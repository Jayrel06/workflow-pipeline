#!/usr/bin/env node
/**
 * Checks code quality of n8n workflow
 */

const fs = require('fs');

function checkCodeQuality(workflowPath) {
    const errors = [];
    const warnings = [];
    const suggestions = [];

    try {
        const content = fs.readFileSync(workflowPath, 'utf8');
        const workflow = JSON.parse(content);

        if (!workflow.nodes) {
            errors.push({
                type: 'NO_NODES',
                severity: 'CRITICAL',
                message: 'Workflow has no nodes'
            });
            return { errors, warnings, suggestions };
        }

        // Check node naming consistency
        const nodeNames = workflow.nodes.map(n => n.name);
        const hasConsistentNaming = nodeNames.every(name => {
            // Check if names follow a pattern (Title Case or sentence case)
            return /^[A-Z][a-z]/.test(name) || /^[a-z]/.test(name);
        });

        if (!hasConsistentNaming) {
            warnings.push({
                type: 'INCONSISTENT_NAMING',
                severity: 'LOW',
                message: 'Node naming is inconsistent (mix of Title Case and lowercase)'
            });
        }

        // Check for magic numbers in parameters
        workflow.nodes.forEach(node => {
            const paramsStr = JSON.stringify(node.parameters);

            // Look for numeric values that should probably be variables
            const hasLargeMagicNumbers = paramsStr.match(/:\s*\d{4,}/);
            if (hasLargeMagicNumbers) {
                suggestions.push({
                    type: 'MAGIC_NUMBER',
                    severity: 'LOW',
                    node: node.name,
                    message: 'Node has large numeric values - consider using variables',
                    hint: 'Use {{$env.VARIABLE}} for configuration values'
                });
            }

            // Check for complex expressions that should be split
            if (paramsStr.includes('={{') && paramsStr.length > 500) {
                const expressionCount = (paramsStr.match(/={{\s*/g) || []).length;
                if (expressionCount > 5) {
                    warnings.push({
                        type: 'COMPLEX_EXPRESSIONS',
                        severity: 'MEDIUM',
                        node: node.name,
                        message: `Node has ${expressionCount} expressions - consider simplifying`,
                        hint: 'Break complex logic into multiple nodes'
                    });
                }
            }
        });

        // Check for proper error handling distribution
        const nodesWithErrorHandling = workflow.nodes.filter(n =>
            n.continueOnFail === true || n.onError
        ).length;

        const apiNodes = workflow.nodes.filter(n =>
            n.type.includes('http') ||
            n.type.includes('api') ||
            n.type.includes('database')
        ).length;

        if (apiNodes > 0 && nodesWithErrorHandling < apiNodes * 0.5) {
            warnings.push({
                type: 'INSUFFICIENT_ERROR_HANDLING',
                severity: 'MEDIUM',
                message: `Only ${nodesWithErrorHandling}/${apiNodes} API nodes have error handling`,
                hint: 'Add error handling to API/database nodes'
            });
        }

        // Check workflow organization (node positions)
        const positions = workflow.nodes.map(n => n.position);
        const hasOrganizedLayout = positions.every((pos, i) => {
            if (i === 0) return true;
            const prevPos = positions[i - 1];
            // Check if there's a reasonable flow (left-to-right or top-to-bottom)
            return pos[0] >= prevPos[0] - 200 || pos[1] >= prevPos[1] - 200;
        });

        if (!hasOrganizedLayout) {
            suggestions.push({
                type: 'DISORGANIZED_LAYOUT',
                severity: 'LOW',
                message: 'Node layout could be more organized',
                hint: 'Arrange nodes in clear left-to-right or top-to-bottom flow'
            });
        }

        // Check for unused nodes (nodes with no connections)
        if (workflow.connections) {
            const connectedNodeIds = new Set();
            Object.keys(workflow.connections).forEach(sourceId => {
                connectedNodeIds.add(sourceId);
                Object.values(workflow.connections[sourceId]).forEach(outputs => {
                    outputs.forEach(targets => {
                        targets.forEach(target => {
                            if (target.node) connectedNodeIds.add(target.node);
                        });
                    });
                });
            });

            const unusedNodes = workflow.nodes.filter(n =>
                !connectedNodeIds.has(n.id) &&
                n.type !== 'n8n-nodes-base.start' &&
                n.type !== 'n8n-nodes-base.webhook'
            );

            unusedNodes.forEach(node => {
                warnings.push({
                    type: 'UNUSED_NODE',
                    severity: 'MEDIUM',
                    node: node.name,
                    message: 'Node is not connected to workflow - is this intentional?'
                });
            });
        }

        // Check for duplicate functionality
        const nodeTypeGroups = {};
        workflow.nodes.forEach(node => {
            const type = node.type;
            if (!nodeTypeGroups[type]) {
                nodeTypeGroups[type] = [];
            }
            nodeTypeGroups[type].push(node);
        });

        Object.entries(nodeTypeGroups).forEach(([type, nodes]) => {
            if (nodes.length > 3 && !type.includes('if') && !type.includes('switch')) {
                suggestions.push({
                    type: 'POSSIBLE_DUPLICATION',
                    severity: 'LOW',
                    message: `Workflow has ${nodes.length} nodes of type ${type}`,
                    hint: 'Consider consolidating similar operations'
                });
            }
        });

    } catch (error) {
        errors.push({
            type: 'ANALYSIS_ERROR',
            severity: 'HIGH',
            message: `Failed to analyze code quality: ${error.message}`
        });
    }

    return { errors, warnings, suggestions };
}

// CLI usage
if (require.main === module) {
    const workflowPath = process.argv[2];

    if (!workflowPath) {
        console.error('Usage: node code-quality.js <workflow.json>');
        process.exit(1);
    }

    const result = checkCodeQuality(workflowPath);

    console.log('\n### Code Quality Analysis\n');

    if (result.errors.length === 0 && result.warnings.length === 0 && result.suggestions.length === 0) {
        console.log('✅ Code quality is excellent\n');
        process.exit(0);
    }

    if (result.errors.length > 0) {
        console.log(`❌ Found ${result.errors.length} errors:\n`);
        result.errors.forEach(error => {
            console.log(`- **${error.severity}**: ${error.message}`);
            console.log();
        });
    }

    if (result.warnings.length > 0) {
        console.log(`⚠️  Found ${result.warnings.length} warnings:\n`);
        result.warnings.forEach(warning => {
            console.log(`- **${warning.severity}**: ${warning.message}`);
            if (warning.node) console.log(`  Node: ${warning.node}`);
            if (warning.hint) console.log(`  Hint: ${warning.hint}`);
            console.log();
        });
    }

    if (result.suggestions.length > 0) {
        console.log(`💡 Found ${result.suggestions.length} suggestions:\n`);
        result.suggestions.forEach(suggestion => {
            console.log(`- ${suggestion.message}`);
            if (suggestion.hint) console.log(`  Hint: ${suggestion.hint}`);
            console.log();
        });
    }

    // Exit with error only if there are actual errors
    process.exit(result.errors.length > 0 ? 1 : 0);
}

module.exports = { checkCodeQuality };
