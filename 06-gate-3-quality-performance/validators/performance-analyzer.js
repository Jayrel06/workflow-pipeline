#!/usr/bin/env node
/**
 * Analyzes workflow performance characteristics
 */

const fs = require('fs');

function analyzePerformance(workflowPath) {
    const issues = [];
    const recommendations = [];

    try {
        const content = fs.readFileSync(workflowPath, 'utf8');
        const workflow = JSON.parse(content);

        if (!workflow.nodes) {
            issues.push({
                type: 'NO_NODES',
                severity: 'CRITICAL',
                message: 'Cannot analyze performance without nodes'
            });
            return { issues, recommendations };
        }

        // Calculate complexity score
        const nodeCount = workflow.nodes.length;
        const connectionCount = workflow.connections ?
            Object.values(workflow.connections).reduce((sum, outputs) => {
                return sum + Object.values(outputs).reduce((s, targets) => s + targets.length, 0);
            }, 0) : 0;

        const complexityScore = Math.round((nodeCount * 1.5 + connectionCount) / 2);

        console.log(`\n📊 Performance Metrics:`);
        console.log(`   Nodes: ${nodeCount}`);
        console.log(`   Connections: ${connectionCount}`);
        console.log(`   Complexity Score: ${complexityScore}/100`);
        console.log();

        // Check for sequential HTTP requests that could be parallel
        const httpNodes = workflow.nodes.filter(n =>
            n.type === 'n8n-nodes-base.httpRequest'
        );

        if (httpNodes.length > 1 && workflow.connections) {
            // Check if HTTP nodes are sequential
            let sequentialHttpCount = 0;
            httpNodes.forEach((node, i) => {
                if (i > 0) {
                    const prevNode = httpNodes[i - 1];
                    // Check if this node comes right after previous HTTP node
                    const connections = workflow.connections[prevNode.id];
                    if (connections) {
                        const isDirectlyConnected = Object.values(connections).some(outputs =>
                            outputs.some(targets =>
                                targets.some(t => t.node === node.id)
                            )
                        );
                        if (isDirectlyConnected) sequentialHttpCount++;
                    }
                }
            });

            if (sequentialHttpCount > 0) {
                recommendations.push({
                    type: 'PARALLEL_REQUESTS',
                    severity: 'MEDIUM',
                    message: `Found ${sequentialHttpCount} sequential HTTP requests`,
                    improvement: 'Consider making independent requests parallel',
                    hint: 'Use SplitInBatches node to process requests concurrently'
                });
            }
        }

        // Check for missing rate limiting on API calls
        const apiNodes = workflow.nodes.filter(n =>
            n.type.includes('http') || n.type.includes('api')
        );

        if (apiNodes.length > 5) {
            const hasRateLimiting = workflow.nodes.some(n =>
                n.type === 'n8n-nodes-base.wait' ||
                n.name.toLowerCase().includes('rate') ||
                n.name.toLowerCase().includes('throttle')
            );

            if (!hasRateLimiting) {
                recommendations.push({
                    type: 'NO_RATE_LIMITING',
                    severity: 'HIGH',
                    message: `${apiNodes.length} API calls without rate limiting`,
                    improvement: 'Add rate limiting to avoid API throttling',
                    hint: 'Insert Wait nodes between API calls or use SplitInBatches with delay'
                });
            }
        }

        // Check for large data processing without pagination
        const dataNodes = workflow.nodes.filter(n =>
            n.type.includes('googleSheets') ||
            n.type.includes('database') ||
            n.type.includes('airtable')
        );

        if (dataNodes.length > 0) {
            const hasPagination = workflow.nodes.some(n =>
                n.type === 'n8n-nodes-base.splitInBatches' ||
                n.name.toLowerCase().includes('paginate') ||
                n.name.toLowerCase().includes('batch')
            );

            if (!hasPagination && dataNodes.length > 2) {
                recommendations.push({
                    type: 'NO_PAGINATION',
                    severity: 'MEDIUM',
                    message: 'Large data operations without pagination',
                    improvement: 'Add pagination for large datasets',
                    hint: 'Use SplitInBatches node to process data in chunks'
                });
            }
        }

        // Check for inefficient data transformations
        const setNodes = workflow.nodes.filter(n => n.type === 'n8n-nodes-base.set');
        if (setNodes.length > 5) {
            recommendations.push({
                type: 'MULTIPLE_TRANSFORMATIONS',
                severity: 'LOW',
                message: `${setNodes.length} Set nodes - data transformation could be more efficient`,
                improvement: 'Consider combining multiple Set nodes into fewer operations',
                hint: 'Merge adjacent Set nodes when possible'
            });
        }

        // Estimate execution time
        let estimatedTime = 0;
        workflow.nodes.forEach(node => {
            // Rough estimates in seconds
            if (node.type.includes('http')) estimatedTime += 2;
            else if (node.type.includes('database')) estimatedTime += 1;
            else if (node.type.includes('googleSheets')) estimatedTime += 3;
            else if (node.type === 'n8n-nodes-base.wait') {
                // Try to extract wait time from parameters
                const waitTime = node.parameters?.amount || 1;
                estimatedTime += waitTime;
            }
            else estimatedTime += 0.1;
        });

        console.log(`⏱️  Estimated Execution Time: ${estimatedTime.toFixed(1)} seconds\n`);

        if (estimatedTime > 30) {
            issues.push({
                type: 'SLOW_EXECUTION',
                severity: 'MEDIUM',
                message: `Estimated execution time is ${estimatedTime.toFixed(1)}s`,
                improvement: 'Consider optimizing for faster execution',
                hint: 'Review if all operations are necessary or can be optimized'
            });
        }

    } catch (error) {
        issues.push({
            type: 'ANALYSIS_ERROR',
            severity: 'HIGH',
            message: `Failed to analyze performance: ${error.message}`
        });
    }

    return { issues, recommendations };
}

// CLI usage
if (require.main === module) {
    const workflowPath = process.argv[2];

    if (!workflowPath) {
        console.error('Usage: node performance-analyzer.js <workflow.json>');
        process.exit(1);
    }

    const result = analyzePerformance(workflowPath);

    console.log('\n### Performance Analysis\n');

    if (result.issues.length === 0 && result.recommendations.length === 0) {
        console.log('✅ Performance is good\n');
        process.exit(0);
    }

    if (result.issues.length > 0) {
        console.log(`⚠️  Found ${result.issues.length} performance issues:\n`);
        result.issues.forEach(issue => {
            console.log(`- **${issue.severity}**: ${issue.message}`);
            if (issue.improvement) console.log(`  Improvement: ${issue.improvement}`);
            if (issue.hint) console.log(`  Hint: ${issue.hint}`);
            console.log();
        });
    }

    if (result.recommendations.length > 0) {
        console.log(`💡 Performance recommendations:\n`);
        result.recommendations.forEach(rec => {
            console.log(`- ${rec.message}`);
            if (rec.improvement) console.log(`  Improvement: ${rec.improvement}`);
            if (rec.hint) console.log(`  Hint: ${rec.hint}`);
            console.log();
        });
    }

    process.exit(0);
}

module.exports = { analyzePerformance };
