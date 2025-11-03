#!/usr/bin/env node
/**
 * Scans for security issues - hardcoded credentials, API keys, etc.
 */

const fs = require('fs');

function scanSecurity(workflowPath) {
    const errors = [];
    const warnings = [];

    try {
        const content = fs.readFileSync(workflowPath, 'utf8');
        const workflow = JSON.parse(content);

        // Patterns that indicate hardcoded secrets
        const secretPatterns = [
            { pattern: /['"](?:api[_-]?key|apikey)['"]:\s*['"]((?!{{|\$env).{10,})['"]/gi, name: 'API Key' },
            { pattern: /['"](?:secret|token|password|passwd|pwd)['"]:\s*['"]((?!{{|\$env).{8,})['"]/gi, name: 'Secret/Password' },
            { pattern: /['"](?:access[_-]?token)['"]:\s*['"]((?!{{|\$env).{10,})['"]/gi, name: 'Access Token' },
            { pattern: /sk-[a-zA-Z0-9]{20,}/g, name: 'OpenAI API Key' },
            { pattern: /xoxb-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24,}/g, name: 'Slack Token' },
            { pattern: /ghp_[a-zA-Z0-9]{36}/g, name: 'GitHub Token' },
            { pattern: /AIza[0-9A-Za-z\\-_]{35}/g, name: 'Google API Key' },
        ];

        const contentStr = JSON.stringify(workflow);

        secretPatterns.forEach(({ pattern, name }) => {
            const matches = contentStr.match(pattern);
            if (matches) {
                matches.forEach(match => {
                    // Check if it's using n8n expression syntax
                    if (!match.includes('{{') && !match.includes('$env')) {
                        errors.push({
                            type: 'HARDCODED_SECRET',
                            severity: 'CRITICAL',
                            secretType: name,
                            message: `Possible hardcoded ${name} detected`,
                            hint: 'Use {{$env.VARIABLE_NAME}} instead'
                        });
                    }
                });
            }
        });

        // Check for environment variable usage (good practice)
        const hasEnvVars = contentStr.includes('$env') || contentStr.includes('{{$env');
        if (!hasEnvVars && workflow.nodes && workflow.nodes.length > 2) {
            warnings.push({
                type: 'NO_ENV_VARS',
                severity: 'MEDIUM',
                message: 'Workflow does not use environment variables - consider using them for configuration'
            });
        }

        // Check each node for security issues
        if (workflow.nodes) {
            workflow.nodes.forEach(node => {
                // Check HTTP nodes for hardcoded URLs with credentials
                if (node.type === 'n8n-nodes-base.httpRequest') {
                    const params = JSON.stringify(node.parameters || {});
                    if (params.match(/https?:\/\/[^:]+:[^@]+@/)) {
                        errors.push({
                            type: 'CREDENTIALS_IN_URL',
                            severity: 'CRITICAL',
                            node: node.name,
                            message: 'HTTP URL contains embedded credentials - use authentication settings instead'
                        });
                    }
                }
            });
        }

    } catch (error) {
        errors.push({
            type: 'SCAN_ERROR',
            severity: 'HIGH',
            message: `Failed to scan for security issues: ${error.message}`
        });
    }

    return { errors, warnings };
}

// CLI usage
if (require.main === module) {
    const workflowPath = process.argv[2];

    if (!workflowPath) {
        console.error('Usage: node security-scanner.js <workflow-file>');
        process.exit(1);
    }

    const result = scanSecurity(workflowPath);

    console.log('\n### Security Scan\n');

    if (result.errors.length === 0 && result.warnings.length === 0) {
        console.log('✅ No security issues found\n');
        process.exit(0);
    } else {
        if (result.errors.length > 0) {
            console.log(`❌ Found ${result.errors.length} CRITICAL security issues:\n`);
            result.errors.forEach(error => {
                console.log(`- **${error.severity}**: ${error.message}`);
                if (error.node) console.log(`  Node: ${error.node}`);
                if (error.hint) console.log(`  Fix: ${error.hint}`);
                console.log();
            });
        }

        if (result.warnings.length > 0) {
            console.log(`⚠️  Found ${result.warnings.length} security warnings:\n`);
            result.warnings.forEach(warning => {
                console.log(`- **${warning.severity}**: ${warning.message}`);
                console.log();
            });
        }

        process.exit(result.errors.length > 0 ? 1 : 0);
    }
}

module.exports = { scanSecurity };
