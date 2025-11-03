#!/usr/bin/env node
/**
 * Validates n8n workflow JSON structure
 */

const fs = require('fs');
const path = require('path');

function validateJSONStructure(workflowPath) {
    const errors = [];
    const warnings = [];

    try {
        const content = fs.readFileSync(workflowPath, 'utf8');
        const workflow = JSON.parse(content);

        // Required top-level fields
        const requiredFields = ['name', 'nodes', 'connections'];
        requiredFields.forEach(field => {
            if (!workflow[field]) {
                errors.push({
                    type: 'MISSING_FIELD',
                    severity: 'CRITICAL',
                    field: field,
                    message: `Missing required field: ${field}`
                });
            }
        });

        // Validate nodes array
        if (!Array.isArray(workflow.nodes)) {
            errors.push({
                type: 'INVALID_TYPE',
                severity: 'CRITICAL',
                field: 'nodes',
                message: 'nodes must be an array'
            });
        } else {
            // Check each node
            workflow.nodes.forEach((node, index) => {
                const requiredNodeFields = ['id', 'name', 'type', 'typeVersion', 'position', 'parameters'];
                requiredNodeFields.forEach(field => {
                    if (node[field] === undefined) {
                        errors.push({
                            type: 'MISSING_NODE_FIELD',
                            severity: 'HIGH',
                            node: node.name || `Node ${index}`,
                            field: field,
                            message: `Node missing required field: ${field}`
                        });
                    }
                });

                // Validate position
                if (node.position && (!Array.isArray(node.position) || node.position.length !== 2)) {
                    errors.push({
                        type: 'INVALID_POSITION',
                        severity: 'MEDIUM',
                        node: node.name,
                        message: 'Node position must be [x, y] array'
                    });
                }

                // Check for duplicate IDs
                const duplicates = workflow.nodes.filter(n => n.id === node.id);
                if (duplicates.length > 1) {
                    errors.push({
                        type: 'DUPLICATE_ID',
                        severity: 'CRITICAL',
                        node: node.name,
                        id: node.id,
                        message: `Duplicate node ID: ${node.id}`
                    });
                }
            });
        }

        // Validate connections
        if (workflow.connections && typeof workflow.connections === 'object') {
            const nodeIds = new Set(workflow.nodes.map(n => n.id));

            Object.entries(workflow.connections).forEach(([sourceId, outputs]) => {
                if (!nodeIds.has(sourceId)) {
                    errors.push({
                        type: 'INVALID_CONNECTION',
                        severity: 'HIGH',
                        source: sourceId,
                        message: `Connection source node does not exist: ${sourceId}`
                    });
                }

                // Check targets
                Object.values(outputs).forEach(outputList => {
                    if (Array.isArray(outputList)) {
                        outputList.forEach(targets => {
                            if (Array.isArray(targets)) {
                                targets.forEach(target => {
                                    if (target.node && !nodeIds.has(target.node)) {
                                        errors.push({
                                            type: 'INVALID_CONNECTION',
                                            severity: 'HIGH',
                                            target: target.node,
                                            message: `Connection target node does not exist: ${target.node}`
                                        });
                                    }
                                });
                            }
                        });
                    }
                });
            });
        }

    } catch (error) {
        errors.push({
            type: 'JSON_PARSE_ERROR',
            severity: 'CRITICAL',
            message: `Failed to parse JSON: ${error.message}`
        });
    }

    return { errors, warnings };
}

// CLI usage
if (require.main === module) {
    const workflowPath = process.argv[2];

    if (!workflowPath) {
        console.error('Usage: node json-structure.js <workflow-file>');
        process.exit(1);
    }

    const result = validateJSONStructure(workflowPath);

    console.log('\n### JSON Structure Validation\n');

    if (result.errors.length === 0) {
        console.log('✅ JSON structure is valid\n');
        process.exit(0);
    } else {
        console.log(`❌ Found ${result.errors.length} errors:\n`);
        result.errors.forEach(error => {
            console.log(`- **${error.severity}**: ${error.message}`);
            if (error.node) console.log(`  Node: ${error.node}`);
            if (error.field) console.log(`  Field: ${error.field}`);
            console.log();
        });
        process.exit(1);
    }
}

module.exports = { validateJSONStructure };
