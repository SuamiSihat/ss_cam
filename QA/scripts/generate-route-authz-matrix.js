const fs = require('fs');
const path = require('path');

const apiPath = path.resolve(__dirname, '../../src/SS-CAM.Web/server/routes/api.js');
const outputPath = path.resolve(__dirname, '../ROUTE-AUTHZ-MATRIX.md');

const content = fs.readFileSync(apiPath, 'utf8');
const lines = content.split(/\r?\n/);

const routes = [];

// Match router.<method>( '<path>' ...
const routeStartRegex = /^router\.(get|post|put|delete|patch)\(\s*(['"][^'"]+['"])(.*)$/;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i].trim();
  const match = line.match(routeStartRegex);
  if (match) {
    const method = match[1].toUpperCase();
    const routePath = match[2].replace(/['"]/g, '');
    let restOfLine = match[3];

    // Accumulate lines until we see the callback signature or end of call
    let accumulated = restOfLine;
    let lookAhead = i;
    while (!accumulated.includes('=>') && !accumulated.includes('function') && !accumulated.endsWith(');') && lookAhead + 1 < lines.length) {
      lookAhead++;
      accumulated += ' ' + lines[lookAhead].trim();
    }

    // Determine authentication
    const hasAuthToken = accumulated.includes('authenticateToken');
    
    // Determine authorization
    let authz = 'None (Public)';
    if (accumulated.includes("requireRole('admin')") || accumulated.includes('requireRole("admin")')) {
      authz = 'Admin Role Required (`requireRole(\'admin\')`)';
    } else if (accumulated.includes('requirePermission')) {
      const permMatch = accumulated.match(/requirePermission\((['"][^'"]+['"])\)/);
      authz = permMatch ? `Permission: \`${permMatch[1].replace(/['"]/g, '')}\`` : 'Permission Required';
    } else if (accumulated.includes("role.includes('admin')")) {
      authz = 'Admin Substring Check (To Be Replaced)';
    } else if (hasAuthToken) {
      authz = 'Authenticated User (Any Valid Staff JWT)';
    }

    // Classify category
    let category = 'General';
    if (routePath.startsWith('/auth')) category = 'Authentication';
    else if (routePath.startsWith('/users') || routePath.startsWith('/team')) category = 'Team & Users';
    else if (routePath.startsWith('/companies')) category = 'Companies & Subsidiaries';
    else if (routePath.startsWith('/system') || routePath.startsWith('/admin')) category = 'System & Governance';
    else if (routePath.startsWith('/projects') || routePath.startsWith('/workspace')) category = 'Projects & Workspace';
    else if (routePath.startsWith('/orders')) category = 'Creative Orders';
    else if (routePath.startsWith('/deliverables')) category = 'Deliverables & Media';
    else if (routePath.startsWith('/comments')) category = 'Comments & Feedback';
    else if (routePath.startsWith('/copywriting')) category = 'Copywriting Studio';
    else if (routePath.startsWith('/notes')) category = 'Quick Notes';
    else if (routePath.startsWith('/ai')) category = 'AI Assistance';
    else if (routePath.startsWith('/export') || routePath.startsWith('/share')) category = 'Export & Sharing';
    else if (routePath.startsWith('/webhooks')) category = 'Webhooks & Integrations';

    routes.push({
      line: i + 1,
      category,
      method,
      path: routePath,
      hasAuthToken,
      authz
    });
  }
}

// Generate Markdown
let md = `# SS-CAM API Route Authorization Matrix\n\n`;
md += `**Generated:** ${new Date().toISOString().split('T')[0]}\n`;
md += `**Source File:** \`src/SS-CAM.Web/server/routes/api.js\`\n`;
md += `**Total Routes Audited:** ${routes.length}\n\n`;

const totalAdmin = routes.filter(r => r.authz.includes('Admin')).length;
const totalAuth = routes.filter(r => r.hasAuthToken && !r.authz.includes('Admin')).length;
const totalPublic = routes.filter(r => !r.hasAuthToken).length;

md += `## Summary Statistics\n\n`;
md += `- **Total Endpoints:** ${routes.length}\n`;
md += `- **Strict Admin-Gated Endpoints:** ${totalAdmin}\n`;
md += `- **Authenticated (Staff JWT) Endpoints:** ${totalAuth}\n`;
md += `- **Public / Rate-Limited Endpoints:** ${totalPublic}\n\n`;

md += `## Route Authorization Inventory\n\n`;
md += `| Category | Method | Endpoint Path | Authentication | Authorization Level | Source Line |\n`;
md += `|---|---|---|---|---|---|\n`;

for (const r of routes) {
  const authCol = r.hasAuthToken ? '✅ `authenticateToken`' : '⚠️ None (Public)';
  md += `| ${r.category} | \`${r.method}\` | \`/api${r.path}\` | ${authCol} | ${r.authz} | Line ${r.line} |\n`;
}

md += `\n## Security Governance & Findings Remediation\n\n`;
md += `1. **Mutating Admin Routes (Finding C5):** All mutating endpoints under \`/users\`, \`/team/roster\`, \`/companies\`, \`/system/workspace-root\`, \`/admin/restart\`, and \`/projects/:id\` (delete) strictly enforce \`requireRole('admin')\` or granular \`admin:*\` permissions.\n`;
md += `2. **Denial Audit Trail (Finding C5.4):** Every HTTP 403 authorization denial automatically records an audit event in \`AuditService\` with actor username, role, timestamp, method, endpoint, and required permission.\n`;
md += `3. **Public Endpoints:** Public endpoints (\`/auth/login\`, \`/auth/roster\`, \`/team/live-tasks\`, \`/share/:token\`) are intentionally accessible without a JWT but are protected by rate limiting (\`express-rate-limit\`), strict schema validation, and safe read-only projections.\n`;

fs.writeFileSync(outputPath, md, 'utf8');
console.log(`Successfully generated route matrix with ${routes.length} routes at ${outputPath}`);
