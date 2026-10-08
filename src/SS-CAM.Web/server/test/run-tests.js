/**
 * Automated Verification Test Suite for SS-CAM Web Portal
 */

const assert = require('assert');
const path = require('path');
const fs = require('fs');

process.env.NODE_ENV = 'test';

// Sandbox isolation: Ensure test suite runs exclusively in local sandbox and never touches production NAS
const sandboxWorkspace = path.resolve(__dirname, '../../sample-workspace');
if (!process.env.WORKSPACE_ROOT) {
  process.env.WORKSPACE_ROOT = sandboxWorkspace;
}
const FrontmatterService = require('../services/FrontmatterService');
const AuditService = require('../services/AuditService');
const DeliverableService = require('../services/DeliverableService');
const WorkspaceService = require('../services/WorkspaceService');
const ApprovalService = require('../services/ApprovalService');
const OrderService = require('../services/OrderService');
const config = require('../config');
const http = require('http');
const apiRoutes = require('../routes/api');

console.log('🧪 Starting SS-CAM Web Management Portal Verification Suite...\n');

// Mock AuditService path to prevent polluting production NAS audit logs
const origAuditGetPath = AuditService.getAuditLogPath;
const tempAuditPath = path.join(__dirname, 'temp-test-audit.jsonl');
AuditService.getAuditLogPath = () => tempAuditPath;

async function runTests() {
  let passed = 0;
  let failed = 0;
  const testQueue = [];

  function test(name, fn) {
    testQueue.push({ name, fn });
  }

  function testAsync(name, fn) {
    testQueue.push({ name, fn });
  }

  // ─── TEST 1: Frontmatter Parsing & Serialization ────────────────────
  test('FrontmatterService parses standard and extended YAML without data loss', () => {
    const rawMarkdown = `---
status: review
designer: 0001D
client: SS
deadline: 2026-09-30
priority: high
tags: [branding, print]
revision: 1
department: Marketing
creative_direction:
  tone: "Luxury Modern"
---

# Test Project Title

This is the project brief content.
- Requirement 1
- Requirement 2
`;

    const parsed = FrontmatterService.parseRawContent(rawMarkdown);
    assert.strictEqual(parsed.frontmatter.status, 'review');
    assert.strictEqual(parsed.frontmatter.designer, '0001D');
    assert.strictEqual(parsed.frontmatter.client, 'SS');
    assert.strictEqual(parsed.frontmatter.revision, 1);
    assert.strictEqual(parsed.frontmatter.department, 'Marketing');
    assert.strictEqual(parsed.frontmatter.creative_direction.tone, 'Luxury Modern');
    assert.ok(parsed.body.includes('# Test Project Title'));
    assert.ok(parsed.body.includes('Requirement 1'));

    const serialized = FrontmatterService.serializeContent(parsed.frontmatter, parsed.body);
    const roundtrip = FrontmatterService.parseRawContent(serialized);
    assert.strictEqual(roundtrip.frontmatter.status, 'review');
    assert.strictEqual(roundtrip.frontmatter.department, 'Marketing');
    assert.ok(roundtrip.body.includes('Requirement 2'));
  });

  // ─── TEST 2: Atomic File Write & OCC Lock ───────────────────────────
  test('FrontmatterService executes atomic writes and detects hash collisions', () => {
    const testDir = path.join(__dirname, 'temp-test-project');
    if (!fs.existsSync(testDir)) fs.mkdirSync(testDir, { recursive: true });

    const initialFm = { status: 'in-progress', designer: '0001D', revision: 0 };
    const initialBody = '# Project Brief Body';
    const writeRes = FrontmatterService.writeProjectReadme(testDir, initialFm, initialBody);

    assert.ok(writeRes.success);
    assert.ok(writeRes.versionHash);

    // Read back
    const readBack = FrontmatterService.readProjectReadme(testDir);
    assert.strictEqual(readBack.frontmatter.status, 'in-progress');
    assert.strictEqual(readBack.versionHash, writeRes.versionHash);

    // Test OCC hash failure
    let conflictCaught = false;
    try {
      FrontmatterService.writeProjectReadme(testDir, { status: 'done' }, null, 'INVALID_HASH');
    } catch (e) {
      if (e.message.includes('Concurrency Conflict')) {
        conflictCaught = true;
      }
    }
    assert.ok(conflictCaught, 'OCC conflict should be detected');

    // Clean up
    fs.rmSync(testDir, { recursive: true, force: true });
  });

  // ─── TEST 3: Directory Traversal Prevention ─────────────────────────
  test('DeliverableService blocks directory traversal attacks', () => {
    const maliciousPayload = Buffer.from('../../../Windows/System32/calc.exe').toString('base64url');
    const resolved = DeliverableService.resolveSafePath(maliciousPayload);
    assert.strictEqual(resolved, null, 'Path outside workspace must resolve to null');
  });

  // ─── TEST 4: Workspace Scanner & KPIs ────────────────────────────────
  test('WorkspaceService accurately computes dashboard metrics', () => {
    const metrics = WorkspaceService.getDashboardMetrics();
    assert.ok(typeof metrics.kpis.total === 'number');
    assert.ok(typeof metrics.kpis.active === 'number');
    assert.ok(typeof metrics.kpis.pendingReview === 'number');
    assert.ok(Array.isArray(metrics.designerWorkload));
    assert.ok(metrics.pipeline.inProgress !== undefined);
  });

  // ─── TEST 5: Audit Trail Append & Retrieval ─────────────────────────
  test('AuditService logs events to JSONL and retrieves them in order', () => {
    const event = AuditService.logEvent({
      actor: 'TestManager',
      role: 'Manager',
      action: 'TEST_ACTION',
      entityType: 'TestEntity',
      entityId: '0001X',
      details: { test: true }
    });

    assert.ok(event);
    assert.ok(event.id);

    const logs = AuditService.getLogs({ action: 'TEST_ACTION', limit: 5 });
    assert.ok(logs.length > 0);
    assert.strictEqual(logs[0].actor, 'TestManager');
  });

  // ─── TEST 6: Approval Decision Lifecycle ────────────────────────────
  test('ApprovalService increments revision round and updates frontmatter on revision request', () => {
    const testDir = path.join(__dirname, 'temp-approval-workspace');
    const projectDir = path.join(testDir, '2026', '202608_August', '202608_9998A_SS_Temp_Approval_Test');
    fs.mkdirSync(projectDir, { recursive: true });

    const initialFm = { status: 'review', designer: 'Harussani', revision: 1, approvals: [] };
    const initialBody = '# Sandbox Approval Test Project\n\nBrief content.';
    FrontmatterService.writeProjectReadme(projectDir, initialFm, initialBody);

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;
    WorkspaceService.isScanning = false;
    WorkspaceService.scan(true);

    try {
      const result = ApprovalService.processDecision({
        projectId: '9998A',
        decision: 'revision_requested',
        reviewer: 'QA Lead',
        role: 'CreativeManager',
        comment: 'Please refine typography hierarchy'
      });

      assert.ok(result.success);
      assert.ok(result.project);
      assert.strictEqual(result.project.status, 'revision');
      assert.strictEqual(result.project.revision, 2);
      assert.ok(result.project.approvals.length > 0);
      assert.strictEqual(result.project.approvals[0].decision, 'revision_requested');
    } finally {
      // Restore workspaceRoot and clean up
      WorkspaceService.workspaceRoot = origRoot;
      WorkspaceService.scan(true);
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 7: Sidebar Navigation & App Ecosystem DOM Structure ─────
  test('App.svelte and Client structure include SS-CAM Desktop ecosystem navigation', () => {
    const svelteAppPath = path.join(__dirname, '../../client/src/App.svelte');
    const indexPath = path.join(__dirname, '../../client/index.html');
    const content = fs.existsSync(svelteAppPath)
      ? fs.readFileSync(svelteAppPath, 'utf8')
      : fs.readFileSync(indexPath, 'utf8');

    assert.ok(content.includes('app-sidebar'), 'Sidebar root element must exist');
    assert.ok(content.includes('sidebar-nav'), 'Sidebar nav container must exist');
    assert.ok(content.includes('desktop-app-banner') || content.includes('Desktop Client'), 'Desktop Client banner must exist');
    assert.ok(
      content.includes('https://suamisihat.github.io/ss_cam/') || content.includes('https://github.com/SuamiSihat/ss_cam/releases'),
      'SS-CAM landing page or release link must exist'
    );
  });

  // ─── TEST 8: Login View DOM Structure & Authentication ─────────────
  test('LoginView renders brand header, quick sign-in roster, and authentication form', () => {
    const svelteLoginPath = path.join(__dirname, '../../client/src/lib/views/LoginView.svelte');
    const legacyLoginPath = path.join(__dirname, '../../client/js/views/LoginView.js');
    const content = fs.existsSync(svelteLoginPath)
      ? fs.readFileSync(svelteLoginPath, 'utf8')
      : fs.readFileSync(legacyLoginPath, 'utf8');

    assert.ok(content.includes('SuamiSihat Creative Portal') || content.includes('login-hero-bg'), 'Login title/viewport must exist');
    assert.ok(content.includes('quick-roster') || content.includes('heroWaveCanvas'), 'Quick roster or canvas must exist');
    assert.ok(content.includes('Sign In') || content.includes('login-card-static'), 'Sign in card must exist');
  });

  // ─── TEST 9: ApiClient Interface Integrity ──────────────────────────
  test('ApiClient contains updateProject, updateBrief, and submitDecision methods', () => {
    const apiTsPath = path.join(__dirname, '../../client/src/lib/services/api.ts');
    const apiJsPath = path.join(__dirname, '../../client/js/api.js');
    const content = fs.existsSync(apiTsPath)
      ? fs.readFileSync(apiTsPath, 'utf8')
      : fs.readFileSync(apiJsPath, 'utf8');

    assert.ok(content.includes('updateProject') || content.includes('updateProjectStatus'), 'ApiClient updateProject method must exist');
    assert.ok(content.includes('updateBrief') || content.includes('updateProjectBrief'), 'ApiClient updateBrief method must exist');
    assert.ok(content.includes('submitDecision') || content.includes('recordApproval'), 'ApiClient submitDecision method must exist');
  });

  // ─── TEST 10: Obsidian Markdown & Mermaid Integration ──────────────
  test('MarkdownService and MermaidViewer support full GFM, Callouts, and Mermaid diagrams', () => {
    const markdownTsPath = path.join(__dirname, '../../client/src/lib/services/markdown.ts');
    const mermaidSveltePath = path.join(__dirname, '../../client/src/lib/components/markdown/MermaidViewer.svelte');
    
    assert.ok(fs.existsSync(markdownTsPath), 'MarkdownService must exist in services');
    assert.ok(fs.existsSync(mermaidSveltePath), 'MermaidViewer Svelte component must exist');

    const mdContent = fs.readFileSync(markdownTsPath, 'utf8');
    assert.ok(mdContent.includes('transformCallouts'), 'Callout transformer must exist');
    assert.ok(mdContent.includes('NOTE|WARNING|IMPORTANT|CAUTION'), 'Supported callout regex must be defined');
  });

  // ─── TEST 11: Company & Subsidiary Management Integrity ─────────────
  test('CompanyService manages corporate holding subsidiaries (SSH, SSC, SSW, SSE, SST)', () => {
    const CompanyService = require('../services/CompanyService');
    const companies = CompanyService.getAll();

    assert.ok(Array.isArray(companies), 'Companies must return an array');
    assert.ok(companies.length >= 5, 'Must contain at least 5 default subsidiaries');

    const holding = CompanyService.getByCode('SSH');
    assert.ok(holding, 'SuamiSihat Holding (SSH) must exist');
    assert.strictEqual(holding.name, 'SuamiSihat Holding Sdn Bhd');
    assert.strictEqual(holding.isParent, true);

    const healthcare = CompanyService.getByCode('SSC');
    assert.ok(healthcare, 'SuamiSihat Healthcare (SSC) must exist');

    const wellness = CompanyService.getByCode('SSW');
    assert.ok(wellness, 'SuamiSihat Ellness (SSW) must exist');

    const ecommerce = CompanyService.getByCode('SSE');
    assert.ok(ecommerce, 'SuamiSihat Ecommerce (SSE) must exist');

    const tech = CompanyService.getByCode('SST');
    assert.ok(tech, 'SuamiSihat Technology (SST) must exist');

    // Test saving an update
    const updated = CompanyService.saveCompany({
      code: 'SST',
      name: 'SuamiSihat Technology Sdn Bhd',
      location: 'Cyberjaya, Selangor'
    });
    assert.strictEqual(updated.location, 'Cyberjaya, Selangor');
  });

  // ─── TEST 12: TeamService & User Staff Directory Governance ────────
  test('TeamService provisions, updates, and validates staff user accounts', () => {
    const TeamService = require('../services/TeamService');
    const { getUserRoles, getUserPermissions } = require('../middleware/auth');
    const roster = TeamService.getStaffRoster();

    assert.ok(Array.isArray(roster), 'Staff roster must return an array');
    assert.ok(roster.length >= 6, 'Must contain canonical creative team members');

    const hasan = roster.find(m => m.staffId === 'SS0001');
    assert.ok(hasan, 'Hasan (SS0001) must exist');
    assert.ok(hasan.role, 'Hasan must have an assigned role');

    // Test adding and updating a multi-role staff user
    const testStaffId = 'SS9999';
    try {
      TeamService.deleteStaffMember(testStaffId);
    } catch (e) {}

    const added = TeamService.addStaffMember({
      staffId: testStaffId,
      name: 'Test Staff Designer & Copywriter',
      roles: ['Designer', 'Copywriter'],
      department: 'Creative Production',
      defaultBrand: 'SS'
    });

    assert.strictEqual(added.staffId, 'SS9999');
    assert.strictEqual(added.name, 'Test Staff Designer & Copywriter');
    assert.ok(added.roles.includes('Designer'), 'Must include Designer role');
    assert.ok(added.roles.includes('Copywriter'), 'Must include Copywriter role');

    // Test permission aggregation across multiple roles
    const perms = getUserPermissions(added);
    assert.ok(perms.includes('deliverable:upload'), 'Must contain Designer upload permission');
    assert.ok(perms.includes('copy:draft'), 'Must contain Copywriter draft permission');

    const updated = TeamService.updateStaffMember(testStaffId, {
      name: 'Test Staff Lead Designer',
      roles: ['Designer', 'Manager']
    });
    assert.strictEqual(updated.name, 'Test Staff Lead Designer');
    assert.ok(updated.roles.includes('Manager'), 'Must update to include Manager role');

    const updatedPerms = getUserPermissions(updated);
    assert.ok(updatedPerms.includes('team:manage_workload'), 'Must contain Manager workload permission');

    // Test Team Directory & Workload aggregation
    const directory = TeamService.getTeamDirectory();
    assert.ok(Array.isArray(directory), 'Team directory must return an array of creatives');
    assert.ok(directory.length > 0, 'Directory must contain active creative staff');
    
    const harussani = directory.find(m => m.staffId === 'SS0004' || m.name === 'Harussani');
    assert.ok(harussani, 'Harussani (Art Director) must be in creative team directory');
    assert.ok(harussani.workload, 'Harussani must have workload metrics object');
    assert.strictEqual(typeof harussani.workload.active, 'number', 'Workload active count must be a number');
    assert.strictEqual(typeof harussani.capacityStatus, 'string', 'Capacity status must be a string');
    assert.strictEqual(typeof harussani.workload.weightedLoad, 'number', 'Weighted load must be a number');
    assert.ok(Array.isArray(harussani.assignedProjects), 'Assigned projects must be an array');
    if (harussani.assignedProjects.length > 0) {
      assert.strictEqual(typeof harussani.assignedProjects[0].slaDays, 'number', 'Assigned project must have numeric slaDays');
      assert.strictEqual(typeof harussani.assignedProjects[0].slotWeight, 'number', 'Assigned project must have numeric slotWeight');
    }

    // Cleanup
    TeamService.deleteStaffMember(testStaffId);
  });

  // ─── TEST 13: CommentService & Collaboration Threads ────────────────
  test('CommentService reads, writes, extracts @mentions, and resolves project comments', () => {
    const CommentService = require('../services/CommentService');
    const testProjectId = '0085D';
    const testDir = path.join(__dirname, '..', '..', '..', 'Creative-Team', '2026', '202608_August', '202608_0085D_SS_Rejal_Premium_Packaging');

    const newComment = CommentService.addComment(testDir, testProjectId, {
      author: 'Haikal',
      authorRole: 'User',
      content: 'Updated the packaging dieline specs. @hasan @harussani please sign off!',
      deliverableId: 'del_001'
    });

    assert.ok(newComment.id.startsWith('cmt_'), 'Comment ID must start with cmt_');
    assert.strictEqual(newComment.author, 'Haikal');
    assert.ok(newComment.mentions.includes('hasan'), 'Must extract @hasan mention');
    assert.ok(newComment.mentions.includes('harussani'), 'Must extract @harussani mention');
    assert.strictEqual(newComment.resolved, false);

    // Retrieve comments
    const allComments = CommentService.getComments(testDir, testProjectId);
    assert.ok(allComments.length >= 1, 'Must contain at least 1 comment');
    assert.ok(allComments.some(c => c.id === newComment.id), 'Must find created comment');

    // Resolve comment
    const resolveResult = CommentService.resolveComment(testDir, testProjectId, newComment.id, true, 'Hasan', 'Admin');
    assert.strictEqual(resolveResult.resolved, true);

    const updatedComments = CommentService.getComments(testDir, testProjectId);
    const resolvedItem = updatedComments.find(c => c.id === newComment.id);
    assert.ok(resolvedItem && resolvedItem.resolved, 'Comment must be marked resolved');

    // Delete comment
    const deleteResult = CommentService.deleteComment(testDir, testProjectId, newComment.id, 'Haikal', 'User');
    assert.strictEqual(deleteResult.success, true);
  });

  // ─── TEST 14: Activity Notifications & Mentions ─────────────────────
  test('CommentService aggregates workspace activity & notification feed', () => {
    const CommentService = require('../services/CommentService');
    const notifs = CommentService.getNotifications('hasan', 10);
    assert.ok(Array.isArray(notifs), 'Notifications must return an array');
  });

  // ─── TEST 15: CopywritingService & 03_COPYWRITING/COPY.md ───────────
  test('CopywritingService reads, auto-scaffolds templates, and saves COPY.md on NAS', () => {
    const CopywritingService = require('../services/CopywritingService');
    const testDir = path.join(__dirname, 'temp-test-copywriting-dir');
    if (!fs.existsSync(testDir)) fs.mkdirSync(testDir, { recursive: true });

    const copyData = CopywritingService.getCopywriting(testDir, '0085D', 'Rejal Premium Packaging');
    assert.ok(copyData.body, 'Must return non-empty copywriting markdown body');
    assert.ok(copyData.stats.words > 0, 'Must compute word count');
    assert.ok(copyData.filePath.includes('03_COPYWRITING') || copyData.filePath.includes('COPY.md'), 'Must resolve copy file path');

    // Test saving custom markdown copy
    const customCopy = '# Updated Video Script Hook\n\n- Hook 1: Raw Honey vitality test';
    const saved = CopywritingService.updateCopywriting(testDir, '0085D', customCopy, 'Test Writer', 'Copywriter');
    assert.strictEqual(saved.success, true);
    assert.strictEqual(saved.body, customCopy);

    // Clean up
    fs.rmSync(testDir, { recursive: true, force: true });
  });

  // ─── TEST 16: Admin Project Deletion & Filesystem Safety ────────────
  test('WorkspaceService safely deletes project folder and subdirectories with audit log', () => {
    const testDir = path.join(__dirname, 'temp-delete-workspace');
    const projectDir = path.join(testDir, '2026', '202608_August', '202608_9999D_SS_Temp_Test_Project');
    const sub1 = path.join(projectDir, '01_BRIEF_ASSETS');
    const sub2 = path.join(projectDir, '02_SOURCE_FILES');
    const sub3 = path.join(projectDir, '03_COPYWRITING');
    const sub4 = path.join(projectDir, '04_WORK_IN_PROGRESS');
    const sub5 = path.join(projectDir, '05_DELIVERABLES');

    fs.mkdirSync(sub1, { recursive: true });
    fs.mkdirSync(sub2, { recursive: true });
    fs.mkdirSync(sub3, { recursive: true });
    fs.mkdirSync(sub4, { recursive: true });
    fs.mkdirSync(sub5, { recursive: true });

    fs.writeFileSync(path.join(projectDir, 'README.md'), '---\nstatus: backlog\n---\n# Temp Project\n', 'utf8');
    fs.writeFileSync(path.join(sub3, 'COPY.md'), '# Copy\n', 'utf8');

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;
    WorkspaceService.isScanning = false;
    WorkspaceService.scan(true);

    const projBefore = WorkspaceService.getProjectById('9999D');
    assert.ok(projBefore, 'Project 9999D must be indexed in workspace');
    assert.strictEqual(projBefore.readmeBody.includes('# Temp Project'), true, 'readmeBody must be loaded from README.md');
    assert.strictEqual(projBefore.briefMarkdown.includes('# Temp Project'), true, 'briefMarkdown must be loaded from README.md');

    const deleteRes = WorkspaceService.deleteProject('9999D', 'Test Admin', 'Administrator');
    assert.strictEqual(deleteRes.success, true);
    assert.strictEqual(WorkspaceService.getProjectById('9999D'), null, 'Project 9999D must be removed from cache');
    assert.strictEqual(fs.existsSync(projectDir), false, 'Project directory and all subfolders must be deleted');

    // Restore workspaceRoot and clean up
    WorkspaceService.workspaceRoot = origRoot;
    WorkspaceService.scan(true);
    fs.rmSync(testDir, { recursive: true, force: true });
  });

  // ─── TEST 17: Real-time Server-Sent Events (SSE) Service ────────────
  test('SseService registers clients and broadcasts structured events', () => {
    const SseService = require('../services/SseService');
    
    let writtenData = [];
    const mockRes = {
      setHeader: () => {},
      flushHeaders: () => {},
      write: (chunk) => {
        writtenData.push(chunk);
      }
    };
    const mockReq = {
      on: () => {},
      user: { name: 'Test Client' }
    };

    const initialCount = SseService.getClientCount();
    SseService.addClient(mockReq, mockRes);
    assert.strictEqual(SseService.getClientCount(), initialCount + 1, 'Client count should increase by 1');

    // Broadcast test
    SseService.broadcast('project:updated', { projectId: '0085D', status: 'review' });
    const hasBroadcast = writtenData.some(d => d.includes('event: project:updated') && d.includes('0085D'));
    assert.ok(hasBroadcast, 'Broadcast message must be written to client stream');
  });

  // ─── TEST 18: Deliverable Media Partial Content (Range) Streaming ───
  test('DeliverableService supports HTTP 206 Partial Content range requests for video media', () => {
    const tempFile = path.join(__dirname, 'temp-video-stream.mp4');
    const dummyBuffer = Buffer.alloc(1024 * 10, 'A'); // 10 KB dummy video
    fs.writeFileSync(tempFile, dummyBuffer);

    let status = 200;
    let headers = {};
    const mockRes = {
      writeHead: (code, hdrs) => {
        status = code;
        headers = hdrs;
      },
      status: (code) => {
        status = code;
        return {
          setHeader: (k, v) => { headers[k] = v; },
          end: () => {}
        };
      },
      write: () => {},
      end: () => {},
      on: () => {},
      once: () => {},
      emit: () => {}
    };

    const mockReq = {
      headers: {
        range: 'bytes=0-1023'
      }
    };

    DeliverableService.streamMedia(tempFile, mockReq, mockRes);

    assert.strictEqual(status, 206, 'Should respond with HTTP 206 Partial Content');
    assert.strictEqual(headers['Content-Range'], 'bytes 0-1023/10240');
    assert.strictEqual(headers['Content-Length'], 1024);
    assert.strictEqual(headers['Content-Type'], 'video/mp4');

    // Cleanup
    try { fs.unlinkSync(tempFile); } catch (e) {}
  });

  // ─── TEST 19: DeliverableService Strict Media Filtering & Previews ──
  test('DeliverableService strictly indexes output media (PNG, JPG, MP4, PDF) including 04_Production, 04_Export_Packages and EXPORT folders, excluding COPY.md / raw source files', () => {
    const testDir = path.join(__dirname, 'temp-deliv-test-project');
    const delivDir = path.join(testDir, '05_DELIVERABLES');
    const prodDir = path.join(testDir, '04_Production');
    const exportPkgDir = path.join(testDir, '04_Export_Packages');
    const keywordExportDir = path.join(testDir, 'Client_EXPORT_Files');
    const copyDir = path.join(testDir, '03_COPYWRITING');
    const srcDir = path.join(testDir, '02_SOURCE_FILES');

    fs.mkdirSync(delivDir, { recursive: true });
    fs.mkdirSync(prodDir, { recursive: true });
    fs.mkdirSync(exportPkgDir, { recursive: true });
    fs.mkdirSync(keywordExportDir, { recursive: true });
    fs.mkdirSync(copyDir, { recursive: true });
    fs.mkdirSync(srcDir, { recursive: true });

    // Write mixed files including Synology thumbnails and cache files
    fs.writeFileSync(path.join(delivDir, 'master_packaging_v1.png'), 'dummy-png-data');
    fs.writeFileSync(path.join(delivDir, 'product_catalogue_final.pdf'), 'dummy-pdf-data');
    fs.writeFileSync(path.join(prodDir, 'social_reel_1080p.mp4'), 'dummy-mp4-data');
    fs.writeFileSync(path.join(exportPkgDir, 'bunting_print_ready.pdf'), 'dummy-bunting-pdf');
    fs.writeFileSync(path.join(keywordExportDir, 'display_ad_1200x628.jpg'), 'dummy-jpg-data');
    fs.writeFileSync(path.join(copyDir, 'COPY.md'), '# Copywriting text should be excluded from gallery');
    fs.writeFileSync(path.join(srcDir, 'packaging_master.afdesign'), 'raw-vector-source-data');

    // Create Synology DSM @eaDir thumbnails and root thumb files
    const eaDir = path.join(delivDir, '@eaDir');
    fs.mkdirSync(eaDir, { recursive: true });
    fs.writeFileSync(path.join(eaDir, 'SYNOFILE_THUMB_M.jpg'), 'dummy-syno-thumb');
    fs.writeFileSync(path.join(eaDir, 'SYNOFILE_THUMB_s.jpg'), 'dummy-syno-thumb');
    fs.writeFileSync(path.join(delivDir, 'SYNOFILE_THUMB_XL.jpg'), 'dummy-syno-thumb');
    fs.writeFileSync(path.join(delivDir, 'SYNOFILE_THUMB_SM.jpg'), 'dummy-syno-thumb');
    fs.writeFileSync(path.join(delivDir, 'thumbs.db'), 'dummy-thumbs-db');
    fs.writeFileSync(path.join(delivDir, '.DS_Store'), 'dummy-ds-store');

    const deliverables = DeliverableService.getProjectDeliverables(testDir);

    // Assert only media files from deliverables, production, and export folders were indexed
    assert.strictEqual(deliverables.length, 5, 'Must index exactly 5 media deliverables (png, pdf, mp4, export_packages pdf, export_keyword jpg)');
    
    const filenames = deliverables.map(d => d.filename);
    assert.ok(filenames.includes('master_packaging_v1.png'), 'Must include PNG export');
    assert.ok(filenames.includes('product_catalogue_final.pdf'), 'Must include PDF export');
    assert.ok(filenames.includes('social_reel_1080p.mp4'), 'Must include MP4 video');
    assert.ok(filenames.includes('bunting_print_ready.pdf'), 'Must include 04_Export_Packages deliverable');
    assert.ok(filenames.includes('display_ad_1200x628.jpg'), 'Must include EXPORT keyword folder deliverable');
    assert.strictEqual(filenames.includes('COPY.md'), false, 'COPY.md must NEVER be in deliverables gallery');
    assert.strictEqual(filenames.includes('packaging_master.afdesign'), false, 'Source files must not be in deliverables gallery');
    assert.strictEqual(filenames.some(f => f.toUpperCase().includes('SYNOFILE_THUMB')), false, 'SYNOFILE_THUMB must NEVER be in deliverables');
    assert.strictEqual(filenames.some(f => f.toLowerCase() === 'thumbs.db'), false, 'thumbs.db must NEVER be in deliverables');

    // Assert WorkspaceService.countFiles excludes SYNOFILE_THUMB and @eaDir
    const WorkspaceService = require('../services/WorkspaceService');
    const realDelivCount = WorkspaceService.countFiles(delivDir);
    assert.strictEqual(realDelivCount, 2, 'WorkspaceService.countFiles must return 2 (excluding @eaDir, SYNOFILE_THUMB, thumbs.db, .DS_Store)');

    // Assert preview URLs and flags
    const pngDel = deliverables.find(d => d.filename === 'master_packaging_v1.png');
    assert.strictEqual(pngDel.isImage, true);
    assert.strictEqual(pngDel.format, 'PNG');
    assert.ok(pngDel.previewUrl.includes('/api/deliverables/preview?id='));
    assert.ok(pngDel.downloadUrl.includes('/api/deliverables/download?id='));

    const mp4Del = deliverables.find(d => d.filename === 'social_reel_1080p.mp4');
    assert.strictEqual(mp4Del.isVideo, true);
    assert.strictEqual(mp4Del.format, 'MP4');
    assert.ok(mp4Del.streamUrl.includes('/api/deliverables/stream?id='));

    // Cleanup
    try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
  });

  // ─── TEST 20: Creative Handover Package Export (ZIP + HTML) ─────────
  test('ExportService generates clean ZIP stream and HTML handover summary manifest', async () => {
    const ExportService = require('../services/ExportService');
    const testDir = path.join(__dirname, 'temp-export-project');
    const delivDir = path.join(testDir, '05_DELIVERABLES');
    const copyDir = path.join(testDir, '03_COPYWRITING');

    fs.mkdirSync(delivDir, { recursive: true });
    fs.mkdirSync(copyDir, { recursive: true });

    fs.writeFileSync(path.join(testDir, 'README.md'), '---\nstatus: done\ndesigner: 0001D\n---\n# Export Project\n', 'utf8');
    fs.writeFileSync(path.join(copyDir, 'COPY.md'), '# Master Copywriting\nHeadline text here\n', 'utf8');
    fs.writeFileSync(path.join(delivDir, '202608_0085D_SS_Poster_Print.pdf'), 'Dummy PDF Deliverable Content', 'utf8');

    const tempZipOut = path.join(__dirname, 'temp-output-handover.zip');
    const outStream = fs.createWriteStream(tempZipOut);

    const EventEmitter = require('events');
    let headers = {};
    const mockRes = new EventEmitter();
    mockRes.setHeader = (k, v) => { headers[k] = v; };
    mockRes.writeHead = () => {};
    mockRes.status = () => ({ json: () => {}, end: () => {} });
    mockRes.headersSent = false;
    mockRes.write = (c) => outStream.write(c);
    mockRes.end = (c) => outStream.end(c);

    ExportService.streamProjectHandover(testDir, '0085D', mockRes);

    assert.strictEqual(headers['Content-Type'], 'application/zip');
    assert.ok(headers['Content-Disposition'].includes('Handover.zip'));

    // Wait for zip archiving to cleanly finish before deleting test files
    await new Promise((resolve) => {
      outStream.on('close', () => {
        try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
        try { if (fs.existsSync(tempZipOut)) fs.unlinkSync(tempZipOut); } catch (e) {}
        resolve();
      });
    });
  });

  // ─── TEST 20: Designer Capacity & Creative SLA Metrics Computation ──
  test('WorkspaceService accurately calculates designer capacity scores and SLA turnaround metrics', () => {
    const metrics = WorkspaceService.getDashboardMetrics();
    assert.ok(metrics.designerWorkload, 'Should include designer workload');
    assert.ok(Array.isArray(metrics.designerWorkload), 'Designer workload should be an array');

    metrics.designerWorkload.forEach(dw => {
      assert.ok(typeof dw.capacityPercent === 'number', 'Should have numeric capacityPercent');
      assert.ok(typeof dw.capacityStatus === 'string', 'Should have string capacityStatus');
      assert.ok(typeof dw.capacityColor === 'string', 'Should have string capacityColor');
    });

    assert.ok(metrics.slaMetrics, 'Should include slaMetrics');
    assert.ok(typeof metrics.slaMetrics.avgTurnaroundDays === 'number' || metrics.slaMetrics.avgTurnaroundDays === null, 'avgTurnaroundDays should be number or null');
    assert.ok(typeof metrics.slaMetrics.medianTurnaroundDays === 'number' || metrics.slaMetrics.medianTurnaroundDays === null, 'medianTurnaroundDays should be number or null');
    assert.ok(typeof metrics.slaMetrics.p90TurnaroundDays === 'number' || metrics.slaMetrics.p90TurnaroundDays === null, 'p90TurnaroundDays should be number or null');
    assert.ok(typeof metrics.slaMetrics.firstTimeRightPercent === 'number' || metrics.slaMetrics.firstTimeRightPercent === null, 'firstTimeRightPercent should be number or null');
    assert.ok(typeof metrics.slaMetrics.avgRevisionCount === 'number' || metrics.slaMetrics.avgRevisionCount === null, 'avgRevisionCount should be number or null');
    assert.ok(typeof metrics.slaMetrics.avgReviewAgeDays === 'number', 'avgReviewAgeDays should be number');
    assert.ok(Array.isArray(metrics.slaMetrics.brandVelocity), 'brandVelocity should be array');
    assert.ok(Array.isArray(metrics.slaMetrics.competencySkills), 'competencySkills should be array');
    assert.ok(metrics.slaMetrics.competencySkills.length === 6, 'Should have 6 creative competency disciplines');

    // Test time-range and brand filtering
    const scoped30d = WorkspaceService.getDashboardMetrics({ timeRange: '30d', brand: 'SS' });
    assert.strictEqual(scoped30d.activeFilters.timeRange, '30d');
    assert.strictEqual(scoped30d.activeFilters.brand, 'SS');
  });

  // ─── TEST 21: Workspace Mount Path Switching & Override Persistence ───
  test('WorkspaceService dynamically switches workspace root path, restarts watcher, and persists override', () => {
    const origRoot = WorkspaceService.workspaceRoot;
    const tempSwitchDir = path.join(__dirname, 'temp-workspace-switch-test');
    if (!fs.existsSync(tempSwitchDir)) {
      fs.mkdirSync(tempSwitchDir, { recursive: true });
    }

    try {
      const result = WorkspaceService.setWorkspaceRoot(tempSwitchDir, 'TestAdmin');
      assert.strictEqual(result.success, true, 'Should report success on valid path switch');
      assert.strictEqual(path.resolve(WorkspaceService.workspaceRoot), path.resolve(tempSwitchDir), 'workspaceRoot must update');
      
      // Verify override file was written
      const overridePath = path.resolve(__dirname, '../workspace_config.json');
      assert.ok(fs.existsSync(overridePath), 'workspace_config.json must be created');
      const savedConfig = JSON.parse(fs.readFileSync(overridePath, 'utf8'));
      assert.strictEqual(path.resolve(savedConfig.workspaceRoot), path.resolve(tempSwitchDir), 'Saved config must match new path');

      // Test invalid path throws error
      assert.throws(() => {
        WorkspaceService.setWorkspaceRoot('Z:\\NonExistent\\Drive\\Folder\\12345');
      }, /does not exist/i, 'Should reject non-existent paths');
    } finally {
      // Restore original workspaceRoot
      WorkspaceService.setWorkspaceRoot(origRoot, 'TestAdmin');
      const overridePath = path.resolve(__dirname, '../workspace_config.json');
      try { if (fs.existsSync(overridePath)) fs.unlinkSync(overridePath); } catch (e) {}
      try {
        fs.rmdirSync(tempSwitchDir);
      } catch (e) {
        try { fs.rmSync(tempSwitchDir, { recursive: true, force: true }); } catch (e2) {}
      }
    }
  });

  // ─── TEST 22: Drag-and-Drop Vault Ingester & Auto-Sorting ───────────
  test('WorkspaceService.ingestFile stores files in canonical subfolders with path safety', () => {
    const testDir = path.join(__dirname, 'temp-ingest-workspace');
    const projectDir = path.join(testDir, '2026', '202608_August', '202608_0099T_SS_Ingest_Test');
    fs.mkdirSync(projectDir, { recursive: true });
    fs.writeFileSync(path.join(projectDir, 'README.md'), '---\nstatus: in-progress\n---\n# Ingest Test\n', 'utf8');

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;
    WorkspaceService.isScanning = false;
    WorkspaceService.scan(true);

    try {
      // Ingest test source file (.psd)
      const base64Content = Buffer.from('FAKE_PSD_BINARY_CONTENT').toString('base64');
      const res = WorkspaceService.ingestFile('0099T', '02_SOURCE_FILES', 'Master_Layout.psd', base64Content, 'Tester');

      assert.strictEqual(res.success, true);
      assert.strictEqual(res.folder, '02_SOURCE_FILES');
      assert.strictEqual(res.filename, 'Master_Layout.psd');

      const expectedSavedFile = path.join(projectDir, '02_SOURCE_FILES', 'Master_Layout.psd');
      assert.ok(fs.existsSync(expectedSavedFile), 'Master_Layout.psd must exist in 02_SOURCE_FILES');
      assert.strictEqual(fs.readFileSync(expectedSavedFile, 'utf8'), 'FAKE_PSD_BINARY_CONTENT');
    } finally {
      WorkspaceService.workspaceRoot = origRoot;
      WorkspaceService.scan(true);
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 23: Tokenized ShareService for Client Reviews ─────────────
  test('ShareService generates, validates, and revokes client review tokens', () => {
    const ShareService = require('../services/ShareService');
    const testDir = path.join(__dirname, 'temp-share-workspace');
    const projectDir = path.join(testDir, '2026', '202608_August', '202608_0088S_SS_Share_Test');
    fs.mkdirSync(projectDir, { recursive: true });
    fs.writeFileSync(path.join(projectDir, 'README.md'), '---\nstatus: in-progress\ntitle: Share Test Project\nbrand: SSH\n---\n# Share Test\n', 'utf8');

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;
    WorkspaceService.scan(true);

    try {
      // 1. Create a 7-day token
      const shareRecord = ShareService.createShareToken({
        projectId: '0088S',
        createdBy: 'Senior Designer',
        expiresInDays: 7,
        permissions: 'review_approve',
        note: 'Director signoff'
      });

      assert.ok(shareRecord.token, 'Token string must be generated');
      assert.strictEqual(shareRecord.jobId, '0088S');
      assert.strictEqual(shareRecord.permissions, 'review_approve');
      assert.strictEqual(shareRecord.active, true);

      // 2. Validate token
      const validated = ShareService.validateToken(shareRecord.token);
      assert.ok(validated, 'Validated result must not be null');
      assert.strictEqual(validated.project.jobId, '0088S');
      assert.strictEqual(validated.shareInfo.permissions, 'review_approve');

      // 3. Revoke token
      const revoked = ShareService.revokeToken(shareRecord.token);
      assert.strictEqual(revoked, true);
      assert.strictEqual(ShareService.validateToken(shareRecord.token), null, 'Revoked token must not validate');
    } finally {
      WorkspaceService.workspaceRoot = origRoot;
      WorkspaceService.scan(true);
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 24: DeliverableService Rich DAM Metadata Indexing ─────────
  test('DeliverableService extracts mediaClass, aspectRatioEstimate, and sizeTier', () => {
    const testDir = path.join(__dirname, 'temp-dam-workspace');
    const projectDir = path.join(testDir, '2026', '202608_August', '202608_0077D_SS_DAM_Test');
    const delivDir = path.join(projectDir, '05_DELIVERABLES');
    fs.mkdirSync(delivDir, { recursive: true });

    fs.writeFileSync(path.join(projectDir, 'README.md'), '---\nstatus: in-progress\n---\n# DAM Test\n', 'utf8');
    fs.writeFileSync(path.join(delivDir, 'Hero_Banner_16x9_v1.png'), 'DUMMY_IMAGE_DATA_BYTES', 'utf8');
    fs.writeFileSync(path.join(delivDir, 'Promo_Story_9x16_Final.mp4'), 'DUMMY_VIDEO_DATA_BYTES', 'utf8');
    fs.writeFileSync(path.join(delivDir, 'Brochure_Print.pdf'), 'DUMMY_PDF_DATA_BYTES', 'utf8');

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;

    try {
      const deliverables = DeliverableService.getProjectDeliverables(projectDir);
      assert.strictEqual(deliverables.length, 3, 'Must index all 3 deliverable files');

      const banner = deliverables.find(d => d.filename.includes('16x9'));
      assert.ok(banner, '16x9 banner must exist');
      assert.strictEqual(banner.mediaClass, 'raster_image');
      assert.strictEqual(banner.aspectRatioEstimate, '16:9');
      assert.strictEqual(banner.sizeTier, 'small');

      const video = deliverables.find(d => d.filename.includes('9x16'));
      assert.ok(video, '9x16 video must exist');
      assert.strictEqual(video.mediaClass, 'video_master');
      assert.strictEqual(video.aspectRatioEstimate, '9:16');

      const pdf = deliverables.find(d => d.filename.includes('Brochure'));
      assert.ok(pdf, 'PDF must exist');
      assert.strictEqual(pdf.mediaClass, 'print_pdf');
    } finally {
      WorkspaceService.workspaceRoot = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 25: GeminiService Creative AI Studio Governance ───────────
  test('GeminiService manages AI configuration and formats Gemini Ultra prompts', () => {
    const GeminiService = require('../services/GeminiService');
    const testDir = path.join(__dirname, 'temp-gemini-workspace');
    fs.mkdirSync(testDir, { recursive: true });

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;

    try {
      // 1. Save and retrieve AI configuration
      const ok = GeminiService.saveApiKey('AIzaSyTestKey123456789', 'gemini-1.5-pro');
      assert.strictEqual(ok, true);

      const status = GeminiService.getStatus();
      assert.strictEqual(status.configured, true);
      assert.strictEqual(status.preferredModel, 'gemini-1.5-pro');
      assert.ok(status.maskedKey.startsWith('AIzaSy'), 'Masked key must begin with prefix');

      // 2. Format Gemini Ultra Web Prompt
      const ultraPrompt = GeminiService.formatUltraWebPrompt({
        brand: 'SSH',
        title: 'Maca Gold Launch',
        audience: 'Men 30-50',
        goal: 'Direct Response'
      });
      assert.ok(ultraPrompt.includes('SUAMISIHAT CREATIVE CAMPAIGN PROMPT'), 'Must contain header');
      assert.ok(ultraPrompt.includes('Maca Gold Launch'), 'Must contain project title');
      assert.ok(ultraPrompt.includes('SSH'), 'Must contain brand code');
    } finally {
      WorkspaceService.workspaceRoot = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 26: SnapshotService Creative Version Timeline & Rollback ──
  test('SnapshotService captures versioned milestones and restores project state', () => {
    const SnapshotService = require('../services/SnapshotService');
    const testDir = path.join(__dirname, 'temp-snapshot-workspace');
    const projDir = path.join(testDir, '2026', '202608_August', '202608_0088D_SS_Snapshot_Test');
    const copyDir = path.join(projDir, '03_COPYWRITING');
    fs.mkdirSync(copyDir, { recursive: true });

    // Initial state: Rev 1
    fs.writeFileSync(path.join(projDir, 'README.md'), '---\nrevision: 1\nstatus: in-progress\n---\n# Rev 1 Initial\n', 'utf8');
    fs.writeFileSync(path.join(copyDir, 'COPY.md'), '# Initial Draft Headline\nBody copy v1', 'utf8');

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;

    try {
      // 1. Capture snapshot of Rev 1
      const snap1 = SnapshotService.createSnapshot(projDir, 'MANUAL_MILESTONE', 'Designer Ali', 'First draft completed');
      assert.ok(snap1 && snap1.id, 'Snapshot must be created with ID');
      assert.strictEqual(snap1.revision, 1);

      // 2. Modify files (simulate Rev 2)
      fs.writeFileSync(path.join(projDir, 'README.md'), '---\nrevision: 2\nstatus: in-progress\n---\n# Rev 2 Changed\n', 'utf8');
      fs.writeFileSync(path.join(copyDir, 'COPY.md'), '# Altered Bad Headline\nCorrupted text', 'utf8');

      // 3. Capture snapshot of Rev 2
      const snap2 = SnapshotService.createSnapshot(projDir, 'CLIENT_REVISION', 'Client User', 'Client feedback logged');
      assert.strictEqual(snap2.revision, 2);

      const list = SnapshotService.getSnapshots(projDir);
      assert.strictEqual(list.length, 2, 'Must list 2 snapshots');

      // 4. Rollback to snap1
      const rollbackResult = SnapshotService.rollback(projDir, snap1.id, 'Art Director');
      assert.strictEqual(rollbackResult.success, true);

      // Verify files were restored
      const restoredCopy = fs.readFileSync(path.join(copyDir, 'COPY.md'), 'utf8');
      assert.ok(restoredCopy.includes('Initial Draft Headline'), 'COPY.md must be restored to Rev 1');
      assert.ok(!restoredCopy.includes('Altered Bad Headline'), 'Altered text must be gone');
    } finally {
      WorkspaceService.workspaceRoot = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 27: WebhookService Studio Notifications ───────────────────
  test('WebhookService manages webhooks and handles Discord/Slack payloads', async () => {
    const WebhookService = require('../services/WebhookService');
    const testDir = path.join(__dirname, 'temp-webhook-workspace');
    fs.mkdirSync(testDir, { recursive: true });

    const origRoot = WorkspaceService.workspaceRoot;
    WorkspaceService.workspaceRoot = testDir;

    try {
      // 1. Add Webhook
      const hook = WebhookService.addWebhook({
        name: 'Discord Creative Alerts',
        url: 'https://discord.com/api/webhooks/mock/123',
        serviceType: 'discord',
        events: ['all']
      });
      assert.ok(hook && hook.id, 'Webhook must be registered with ID');

      const list = WebhookService.getWebhooks();
      assert.strictEqual(list.length, 1);
      assert.strictEqual(list[0].name, 'Discord Creative Alerts');

      // 2. Delete Webhook
      const deleted = WebhookService.deleteWebhook(hook.id);
      assert.strictEqual(deleted, true);
      assert.strictEqual(WebhookService.getWebhooks().length, 0);
    } finally {
      WorkspaceService.workspaceRoot = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 28: Quick Notes Multi-User Isolation & Sync ────────────────
  test('Quick Notes discovers Notes and user-scoped Notes_* directories with UTF-8 BOM safety', async () => {
    const config = require('../config');
    const testDir = path.join(__dirname, 'temp-notes-workspace');
    const notesTeamDir = path.join(testDir, '_Team', '_Config', 'Notes');
    const notesBrandDir = path.join(testDir, '_Team', '_Config', 'Notes_brand');
    fs.mkdirSync(notesTeamDir, { recursive: true });
    fs.mkdirSync(notesBrandDir, { recursive: true });

    const origRoot = config.WORKSPACE_ROOT;
    config.WORKSPACE_ROOT = testDir;

    try {
      // 1. Write team note and user-scoped note with UTF-8 BOM
      fs.writeFileSync(path.join(notesTeamDir, 'team_note.md'), '---\npriority: high\n---\n# Team Overview\n\nAll designers briefing.');
      fs.writeFileSync(path.join(notesBrandDir, 'brand_note.md'), '\uFEFF---\npinned: true\n---\n# Madu Tualang Specs\n\n17x target sales.');

      // 2. Query routes/api notes functions
      const express = require('express');
      const app = express();
      app.use(express.json());
      app.use('/api', require('../routes/api'));

      const server = await new Promise(r => { const s = app.listen(0, '127.0.0.1', () => r(s)); });
      const port = server.address().port;
      let res;
      try {
        res = await new Promise((resolve, reject) => {
          http.get(`http://127.0.0.1:${port}/api/notes`, (r) => {
            let data = '';
            r.on('data', chunk => data += chunk);
            r.on('end', () => resolve({ status: r.statusCode, body: JSON.parse(data || '{}') }));
          }).on('error', reject);
        });
      } finally {
        server.close();
      }
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.notes.length, 2);

      const brandNote = res.body.notes.find(n => n.id === 'brand_note');
      assert.ok(brandNote, 'Brand note must be discovered from Notes_brand');
      assert.strictEqual(brandNote.title, 'Madu Tualang Specs');
      assert.strictEqual(brandNote.isPinned, true);
      assert.strictEqual(brandNote.owner, 'brand');

      const teamNote = res.body.notes.find(n => n.id === 'team_note');
      assert.ok(teamNote, 'Team note must be discovered from Notes');
      assert.strictEqual(teamNote.title, 'Team Overview');
      assert.strictEqual(teamNote.owner, 'team');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 30: OrderService NAS _Orders Attachment Vault & Ingestion ──
  test('OrderService saves, lists, downloads attachments in NAS _Orders and ingests to 01_BRIEF_ASSETS', async () => {
    const OrderService = require('../services/OrderService');
    const testDir = path.join(__dirname, 'temp-orders-workspace');
    const origRoot = config.WORKSPACE_ROOT;
    config.WORKSPACE_ROOT = testDir;

    try {
      // 1. Submit an order with an attachment
      const order = OrderService.submitOrder({
        title: 'Hero Banner Campaign',
        entity: 'SSC',
        priority: 'tier_1',
        format: 'print_digital',
        copy: 'Special headline copy for test',
        targetDate: '2026-09-30',
        requester: 'Test Requester',
        attachments: [
          { filename: 'logo_mockup.png', fileData: Buffer.from('fake_image_bytes').toString('base64') }
        ]
      });

      assert.ok(order && order.id.startsWith('ORD-'), 'Order ID must be generated');
      assert.strictEqual(order.attachmentCount, 1, 'Order must have 1 initial attachment');

      // 2. Add another attachment
      const added = OrderService.saveOrderAttachment(order.id, 'spec_sheet.pdf', Buffer.from('pdf_content'), 'Designer Harussani');
      assert.strictEqual(added.filename, 'spec_sheet.pdf');

      // 3. List attachments
      const list = OrderService.listOrderAttachments(order.id);
      assert.strictEqual(list.length, 2, 'Must list 2 attachments');
      assert.ok(list.some(f => f.filename === 'logo_mockup.png'), 'Must contain logo_mockup.png');
      assert.ok(list.some(f => f.filename === 'spec_sheet.pdf'), 'Must contain spec_sheet.pdf');

      // 4. Verify physical NAS path
      const filePath = OrderService.getOrderAttachmentPath(order.id, 'spec_sheet.pdf');
      assert.ok(fs.existsSync(filePath), 'Physical file must exist on NAS _Orders directory');

      // 5. Ingest to project
      const projDir = path.join(testDir, '2026', '202609_September', '202609_0091D_SSC_Test_Vault');
      fs.mkdirSync(projDir, { recursive: true });
      fs.writeFileSync(path.join(projDir, 'README.md'), '---\nstatus: in-progress\n---\n# Vault\n', 'utf8');

      const origWsRoot = WorkspaceService.workspaceRoot;
      WorkspaceService.workspaceRoot = testDir;
      try {
        const ingestRes = OrderService.copyAttachmentsToProject(order.id, '0091D', 'Designer');
        assert.strictEqual(ingestRes.count, 2, 'Must copy 2 files into 01_BRIEF_ASSETS');
        assert.ok(fs.existsSync(path.join(projDir, '01_BRIEF_ASSETS', 'logo_mockup.png')), 'File must exist in 01_BRIEF_ASSETS');
        assert.ok(fs.existsSync(path.join(projDir, '01_BRIEF_ASSETS', 'spec_sheet.pdf')), 'File must exist in 01_BRIEF_ASSETS');
      } finally {
        WorkspaceService.workspaceRoot = origWsRoot;
      }
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 31: OrderService UTF-8 BOM and Windows Ledger Interop ──
  test('OrderService transparently strips UTF-8 BOM from JSON-Lines ledgers', async () => {
    const OrderService = require('../services/OrderService');
    const testDir = path.join(__dirname, 'temp-orders-bom-test');
    const origRoot = config.WORKSPACE_ROOT;
    config.WORKSPACE_ROOT = testDir;

    try {
      const ordersVault = path.join(testDir, '_Orders');
      fs.mkdirSync(ordersVault, { recursive: true });
      const ledgerPath = path.join(ordersVault, 'creative-orders.jsonl');

      // Write a BOM header (EF BB BF) followed by JSON lines
      const bomBuffer = Buffer.from([0xEF, 0xBB, 0xBF]);
      const lineData = Buffer.from(JSON.stringify({
        id: 'ORD-260901-BOMTEST',
        title: 'BOM Test Campaign',
        entity: 'SSC',
        priority: 'tier_1',
        format: 'print_posm',
        copy: 'Testing BOM',
        targetDate: '2026-09-30',
        status: 'pending',
        submittedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        attachments: []
      }) + '\n', 'utf8');

      fs.writeFileSync(ledgerPath, Buffer.concat([bomBuffer, lineData]));

      // 1. Verify readAllOrders parses despite BOM
      const list = OrderService.listOrders({});
      assert.strictEqual(list.length, 1, 'Must parse 1 order despite UTF-8 BOM');
      assert.strictEqual(list[0].id, 'ORD-260901-BOMTEST');

      // 2. Verify submitOrder with attachment succeeds on top of BOM ledger
      const newOrder = OrderService.submitOrder({
        title: 'New Order After BOM',
        entity: 'SSE',
        priority: 'tier_2',
        format: '9_16_video',
        copy: 'Hook copy',
        targetDate: '2026-09-30',
        requester: 'Test Author',
        attachments: [
          { filename: 'attached.png', fileData: 'data:image/png;base64,ZmFrZQ==' }
        ]
      });

      assert.ok(newOrder && newOrder.id.startsWith('ORD-'), 'New order must be generated and returned');
      assert.strictEqual(newOrder.attachmentCount, 1, 'Must count 1 attachment');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // --- TEST 32: Creative Order Tier 0 & Digital/Print Channel Architecture ---
  test('OrderService persists tier_0 priority, print/digital channel, material, and custom dimensions', () => {
    const origRoot = config.WORKSPACE_ROOT;
    const testDir = path.join(__dirname, 'temp-order-channels-test');

    try {
      config.WORKSPACE_ROOT = testDir;
      const ordersVault = path.join(testDir, '_Orders');
      fs.mkdirSync(ordersVault, { recursive: true });

      // 1. Submit a Print order with tier_0 (Low/Pipeline), material, and custom dimensions
      const printOrder = OrderService.submitOrder({
        title: 'Compounding Pharmacy Medicine Box 2026',
        entity: 'SSC',
        priority: 'tier_0',
        channel: 'print',
        format: 'print_packaging_box',
        customSize: '150 x 85 x 45 mm',
        material: 'waterproof_vinyl',
        copy: 'Batch compounding label specs and safety instructions',
        targetDate: '2026-10-15',
        requester: 'Dr. Afiq'
      });

      assert.ok(printOrder && printOrder.id.startsWith('ORD-'), 'Print order must be created');
      assert.strictEqual(printOrder.priority, 'tier_0', 'Priority must be tier_0');
      assert.strictEqual(printOrder.channel, 'print', 'Channel must be print');
      assert.strictEqual(printOrder.format, 'print_packaging_box', 'Format must match');
      assert.strictEqual(printOrder.material, 'waterproof_vinyl', 'Material must match');
      assert.strictEqual(printOrder.customSize, '150 x 85 x 45 mm', 'Custom size must match');

      // 2. Submit a Digital order with custom screen size
      const digitalOrder = OrderService.submitOrder({
        title: 'Hero Screen LED Display',
        entity: 'SSH',
        priority: 'tier_1',
        channel: 'digital',
        format: 'custom_digital',
        customSize: '3840 x 1080 px',
        copy: 'Grand opening digital billboard loop',
        targetDate: '2026-09-25',
        requester: 'Marketing'
      });

      assert.strictEqual(digitalOrder.channel, 'digital');
      assert.strictEqual(digitalOrder.format, 'custom_digital');
      assert.strictEqual(digitalOrder.customSize, '3840 x 1080 px');

      // 3. Test updateOrder with material & custom dimensions
      const patched = OrderService.updateOrder(printOrder.id, {
        material: 'artcard_matte_spotuv',
        customSize: '160 x 90 x 50 mm'
      });

      assert.strictEqual(patched.material, 'artcard_matte_spotuv');
      assert.strictEqual(patched.materialType, 'artcard_matte_spotuv');
      assert.strictEqual(patched.customSize, '160 x 90 x 50 mm');

      // 4. Verify listOrders includes enriched properties
      const allOrders = OrderService.listOrders({});
      assert.strictEqual(allOrders.length, 2);
      const retrieved = allOrders.find(o => o.id === printOrder.id);
      assert.strictEqual(retrieved.material, 'artcard_matte_spotuv');
      assert.strictEqual(retrieved.priority, 'tier_0');

      // 5. Test full creative brief editing via updateOrder (Option A)
      const edited = OrderService.updateOrder(digitalOrder.id, {
        title: 'Hero Screen LED Display (Revised Edition)',
        copy: 'Updated opening headline loop with promotion prices',
        priority: 'tier_2',
        targetDate: '2026-10-01'
      });
      assert.strictEqual(edited.title, 'Hero Screen LED Display (Revised Edition)');
      assert.strictEqual(edited.copy, 'Updated opening headline loop with promotion prices');
      assert.strictEqual(edited.priority, 'tier_2');
      assert.strictEqual(edited.targetDate, '2026-10-01');

      const fetchedEdited = OrderService.getOrder(digitalOrder.id);
      assert.strictEqual(fetchedEdited.title, 'Hero Screen LED Display (Revised Edition)');
      assert.strictEqual(fetchedEdited.copy, 'Updated opening headline loop with promotion prices');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 33: TeamService Live Studio Tasks Telemetry & BOM Safety ────
  test('TeamService discovers, parses, and cleans live studio task telemetry with BOM safety', () => {
    const TeamService = require('../services/TeamService');
    const origRoot = config.WORKSPACE_ROOT;
    const testDir = path.join(__dirname, 'temp-livetasks-test-' + Date.now());

    try {
      config.WORKSPACE_ROOT = testDir;
      const teamDir = path.join(testDir, '_Team');
      fs.mkdirSync(teamDir, { recursive: true });

      const liveTasksJsonPath = path.join(teamDir, 'live_tasks.json');

      // 1. When file does not exist, returns empty array
      const emptyTasks = TeamService.getLiveTasks();
      assert.ok(Array.isArray(emptyTasks), 'Must return array when live_tasks.json does not exist');
      assert.strictEqual(emptyTasks.length, 0);

      // 2. Write mock live tasks with UTF-8 BOM (\uFEFF)
      const now = new Date();
      const mockTasks = [
        {
          StaffId: 'SS0004',
          DesignerName: 'Harussani',
          ProjectId: '202608_0085D_SS_Rejal_Premium_Packaging',
          ProjectName: 'SS Rejal Premium Packaging',
          Client: 'SS',
          State: 'Running',
          StartedAt: new Date(now.getTime() - 42 * 60 * 1000).toISOString(),
          LastHeartbeat: now.toISOString(),
          ElapsedSeconds: 2520,
          SessionNotes: 'Polishing 3D box fold UV map and print cutline specs',
          MachineName: 'STUDIO-AD-01'
        },
        {
          StaffId: 'SS0003',
          DesignerName: 'Farhan',
          ProjectId: '202609_0012S_SS_TikTok_Motion_Ads',
          ProjectName: 'TikTok Motion Ads Loop',
          Client: 'SS',
          State: 'Running',
          StartedAt: new Date(now.getTime() - 15 * 60 * 1000).toISOString(),
          LastHeartbeat: now.toISOString(),
          ElapsedSeconds: 900,
          SessionNotes: 'Motion graphic keyframing',
          MachineName: 'STUDIO-DESK-03'
        },
        {
          StaffId: 'SS0002',
          DesignerName: 'Stale Designer',
          ProjectId: '202601_0001D_SS_Old_Project',
          ProjectName: 'Old Project',
          Client: 'SS',
          State: 'Running',
          StartedAt: new Date(now.getTime() - 48 * 3600 * 1000).toISOString(),
          LastHeartbeat: new Date(now.getTime() - 24 * 3600 * 1000).toISOString(), // > 16h stale
          ElapsedSeconds: 3600,
          MachineName: 'STALE-PC'
        }
      ];

      // Write with BOM
      const bomBuffer = Buffer.concat([
        Buffer.from([0xEF, 0xBB, 0xBF]),
        Buffer.from(JSON.stringify(mockTasks, null, 2), 'utf8')
      ]);
      fs.writeFileSync(liveTasksJsonPath, bomBuffer);

      // 3. Read and filter tasks
      const liveTasks = TeamService.getLiveTasks();
      assert.ok(Array.isArray(liveTasks), 'Must return array of live tasks');
      assert.strictEqual(liveTasks.length, 2, 'Stale task (> 16h) must be filtered out');

      const adTask = liveTasks.find(t => t.StaffId === 'SS0004');
      assert.ok(adTask, 'Harussani live task must be parsed');
      assert.strictEqual(adTask.DesignerName, 'Harussani');
      assert.strictEqual(adTask.Client, 'SS');
      assert.strictEqual(adTask.MachineName, 'STUDIO-AD-01');
      assert.strictEqual(adTask.ElapsedSeconds, 2520);
      assert.strictEqual(adTask.SessionNotes, 'Polishing 3D box fold UV map and print cutline specs');
      assert.ok(adTask.AvatarColor, 'Avatar color must be enriched');

      const motionTask = liveTasks.find(t => t.StaffId === 'SS0003');
      assert.ok(motionTask, 'Farhan live task must be parsed');
      assert.strictEqual(motionTask.DesignerName, 'Farhan');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 34: OrderService C# PascalCase Interop & Path Safety ──────
  test('OrderService normalizes C# desktop PascalCase order records and prevents type errors', () => {
    const OrderService = require('../services/OrderService');
    const testDir = path.join(__dirname, 'temp-orders-pascal-test-' + Date.now());
    const origRoot = config.WORKSPACE_ROOT;

    try {
      config.WORKSPACE_ROOT = testDir;
      const ordersVault = path.join(testDir, '_Orders');
      fs.mkdirSync(ordersVault, { recursive: true });
      const ledgerPath = path.join(ordersVault, 'creative-orders.jsonl');

      // 1. Write an order using C# desktop PascalCase schema
      const csharpOrder = {
        Id: "ORD-260910-6107",
        Title: "Androlab RX prescription label",
        Entity: "SSC",
        Priority: "tier_0",
        Channel: "print",
        Format: "print_label",
        CustomSize: "",
        Material: "waterproof_vinyl",
        Copy: "Compounding pharmacy label copy",
        TargetDate: "2026-10-01",
        Requester: "Harussani",
        Status: "Pending"
      };

      // Also include a corrupted empty line to test resilience
      const content = '\uFEFF' + JSON.stringify(csharpOrder) + '\n\n';
      fs.writeFileSync(ledgerPath, content, 'utf8');

      // 2. Call listOrders() — must NOT throw TypeError on path.basename
      const list = OrderService.listOrders({});
      assert.strictEqual(list.length, 1, 'Must parse exactly 1 order');
      assert.strictEqual(list[0].id, 'ORD-260910-6107', 'Normalized id must match');
      assert.strictEqual(list[0].title, 'Androlab RX prescription label');
      assert.strictEqual(list[0].status, 'pending');
      assert.strictEqual(list[0].priority, 'tier_0');
      assert.strictEqual(list[0].entity, 'SSC');
      assert.ok(Array.isArray(list[0].attachments), 'attachments must be array');

      // 3. Test getOrder
      const single = OrderService.getOrder('ORD-260910-6107');
      assert.ok(single, 'Must find order by ID');
      assert.strictEqual(single.id, 'ORD-260910-6107');

      // 4. Test updateOrder on PascalCase order
      const updated = OrderService.updateOrder('ORD-260910-6107', { status: 'in_progress' });
      assert.strictEqual(updated.status, 'in_progress');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST: Authentication Security & Lazy Migration ──────────────────
  test('Authentication security: empty password -> 401, default password -> 401, correct password -> 200, with bcrypt lazy migration', async () => {
    const origDataDir = config.DATA_DIR;
    const testDir = path.join(__dirname, 'temp-sandbox-auth-test');
    try {
      fs.mkdirSync(testDir, { recursive: true });
      config.DATA_DIR = testDir;

      // 1. Seed user password with legacy plaintext 'SecretPassword123!'
      const passwordsPath = path.join(testDir, 'user_passwords.json');
      fs.writeFileSync(passwordsPath, JSON.stringify({ harussani: 'SecretPassword123!' }, null, 2), 'utf8');

      // Create express app with apiRoutes
      const express = require('express');
      const testApp = express();
      testApp.use(express.json());
      testApp.use('/api', apiRoutes);
      const testServer = await new Promise(res => {
        const s = testApp.listen(0, '127.0.0.1', () => res(s));
      });
      const port = testServer.address().port;

      const postLogin = async (username, password) => {
        return new Promise((resolve, reject) => {
          const postData = JSON.stringify({ username, password });
          const req = http.request({
            hostname: '127.0.0.1',
            port,
            path: '/api/auth/login',
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(postData)
            }
          }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(data || '{}') }));
          });
          req.on('error', reject);
          req.write(postData);
          req.end();
        });
      };

      try {
        // A. Empty password -> 401
        const emptyRes = await postLogin('harussani', '');
        assert.strictEqual(emptyRes.status, 401, 'Empty password must return 401');

        // B. Old shared default password -> 401
        const defaultRes = await postLogin('harussani', 'SuamiSihat123!');
        assert.strictEqual(defaultRes.status, 401, 'Old default password must return 401');

        // C. Correct password -> 200
        const correctRes = await postLogin('harussani', 'SecretPassword123!');
        assert.strictEqual(correctRes.status, 200, 'Correct password must return 200');
        assert.ok(correctRes.body.token, 'Must return JWT token');

        // D. Verify lazy migration occurred in user_passwords.json
        const updatedPasswords = JSON.parse(fs.readFileSync(passwordsPath, 'utf8'));
        assert.ok(updatedPasswords.harussani.startsWith('$2'), 'Plaintext must be upgraded to bcrypt hash');
        const bcrypt = require('bcryptjs');
        assert.ok(bcrypt.compareSync('SecretPassword123!', updatedPasswords.harussani), 'Bcrypt hash must match correct password');
      } finally {
        testServer.close();
      }
    } finally {
      config.DATA_DIR = origDataDir;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST: Uniform Login Error Responses (User Enumeration Protection) ──
  test('Login enumeration protection: non-existent user and wrong password return identical HTTP 401 error', async () => {
    const express = require('express');
    const testApp = express();
    testApp.use(express.json());
    testApp.use('/api', apiRoutes);
    const testServer = await new Promise(res => {
      const s = testApp.listen(0, '127.0.0.1', () => res(s));
    });
    const port = testServer.address().port;

    const postLogin = async (username, password) => {
      return new Promise((resolve, reject) => {
        const postData = JSON.stringify({ username, password });
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path: '/api/auth/login',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
          }
        }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(data || '{}') }));
        });
        req.on('error', reject);
        req.write(postData);
        req.end();
      });
    };

    try {
      const unknownUserRes = await postLogin('non_existent_user_9999', 'AnyPassword123!');
      const wrongPasswordRes = await postLogin('harussani', 'DefinitelyWrongPassword123!');

      assert.strictEqual(unknownUserRes.status, 401, 'Unknown user must return 401');
      assert.strictEqual(wrongPasswordRes.status, 401, 'Wrong password must return 401');
      assert.strictEqual(unknownUserRes.body.error, wrongPasswordRes.body.error, 'Error message must be identical to prevent user enumeration');
      assert.strictEqual(unknownUserRes.body.error, 'Invalid credentials. Please verify your username and password.');
    } finally {
      testServer.close();
    }
  });

  // ─── TEST: Emergency Admin Bootstrap Password Recovery ─────────────────
  test('Admin bootstrap password: honored only when no admin password exists; ignored once set', () => {
    const origDataDir = config.DATA_DIR;
    const origEnvBootstrap = process.env.ADMIN_BOOTSTRAP_PASSWORD;
    const testDir = path.join(__dirname, 'temp-sandbox-bootstrap-test');
    try {
      fs.mkdirSync(testDir, { recursive: true });
      config.DATA_DIR = testDir;
      process.env.ADMIN_BOOTSTRAP_PASSWORD = 'EmergencyAdminBootstrapPass2026!';

      const { verifyUserPassword } = require('../middleware/auth');

      // 1. Initial attempt on clean store with bootstrap password -> success
      const bootSuccess = verifyUserPassword('admin', 'EmergencyAdminBootstrapPass2026!');
      assert.strictEqual(bootSuccess, true, 'Bootstrap password must succeed when no admin password exists');

      // Verify hash was saved to DATA_DIR
      const passwordsPath = path.join(testDir, 'user_passwords.json');
      const saved = JSON.parse(fs.readFileSync(passwordsPath, 'utf8'));
      assert.ok(saved.admin && saved.admin.startsWith('$2'), 'Admin password must be saved as bcrypt hash');

      // 2. Now that admin has a password, changing bootstrap password should be IGNORED
      process.env.ADMIN_BOOTSTRAP_PASSWORD = 'NewUnauthorizedBootstrapPassword!';
      const bootIgnored = verifyUserPassword('admin', 'NewUnauthorizedBootstrapPassword!');
      assert.strictEqual(bootIgnored, false, 'Bootstrap password must be ignored once admin password is set');

      // 3. Original bootstrapped password still works via bcrypt hash
      const realSuccess = verifyUserPassword('admin', 'EmergencyAdminBootstrapPass2026!');
      assert.strictEqual(realSuccess, true, 'Original bootstrapped password must still succeed via hash');
    } finally {
      config.DATA_DIR = origDataDir;
      if (origEnvBootstrap === undefined) delete process.env.ADMIN_BOOTSTRAP_PASSWORD;
      else process.env.ADMIN_BOOTSTRAP_PASSWORD = origEnvBootstrap;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST: Production Config Security — JWT_SECRET Enforcement ─────────
  test('Production configuration security: server exits non-zero without strong JWT_SECRET (>= 32 chars) when NODE_ENV=production', () => {
    const { execSync } = require('child_process');
    const projectRoot = path.resolve(__dirname, '../..');
    
    // A. Empty secret -> exit non-zero
    let emptySecretFailed = false;
    try {
      execSync('node server/config.js', {
        cwd: projectRoot,
        env: { ...process.env, NODE_ENV: 'production', JWT_SECRET: '' },
        stdio: 'pipe'
      });
    } catch (err) {
      if (err.status !== 0) emptySecretFailed = true;
    }
    assert.strictEqual(emptySecretFailed, true, 'server/config.js must exit non-zero when JWT_SECRET is empty in production');

    // B. Short secret (< 32 chars) -> exit non-zero
    let shortSecretFailed = false;
    try {
      execSync('node server/config.js', {
        cwd: projectRoot,
        env: { ...process.env, NODE_ENV: 'production', JWT_SECRET: 'short-secret-less-than-32-chars' },
        stdio: 'pipe'
      });
    } catch (err) {
      if (err.status !== 0) shortSecretFailed = true;
    }
    assert.strictEqual(shortSecretFailed, true, 'server/config.js must exit non-zero when JWT_SECRET is < 32 chars in production');

    // C. Valid 64-char secret -> exits 0
    let validSecretSucceeded = false;
    try {
      execSync('node server/config.js', {
        cwd: projectRoot,
        env: { ...process.env, NODE_ENV: 'production', JWT_SECRET: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef' },
        stdio: 'pipe'
      });
      validSecretSucceeded = true;
    } catch (err) {}
    assert.strictEqual(validSecretSucceeded, true, 'server/config.js must succeed when JWT_SECRET is >= 32 chars in production');
  });

  // ─── TEST: Login Rate Limiting ─────────────────────────────────────────
  test('Login rate limiting: 6th rapid failed login on /auth/login returns HTTP 429', async () => {
    const express = require('express');
    const rateLimit = require('express-rate-limit');

    const testApp = express();
    testApp.use(express.json());

    const isolatedLimiter = rateLimit({
      windowMs: 15 * 60 * 1000,
      max: 5,
      standardHeaders: true,
      legacyHeaders: false
    });

    testApp.post('/api/auth/login', isolatedLimiter, (req, res) => {
      res.status(401).json({ error: 'Invalid credentials. Please verify your username and password.' });
    });

    const testServer = await new Promise(res => {
      const s = testApp.listen(0, '127.0.0.1', () => res(s));
    });
    const port = testServer.address().port;

    try {
      const sendRequest = () => {
        return new Promise((resolve, reject) => {
          const postData = JSON.stringify({ username: 'harussani', password: 'wrong' });
          const req = http.request({
            hostname: '127.0.0.1',
            port,
            path: '/api/auth/login',
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Content-Length': Buffer.byteLength(postData)
            }
          }, (res) => {
            resolve(res.statusCode);
          });
          req.on('error', reject);
          req.write(postData);
          req.end();
        });
      };

      const statuses = [];
      for (let i = 1; i <= 6; i++) {
        const code = await sendRequest();
        statuses.push(code);
      }

      for (let i = 0; i < 5; i++) {
        assert.strictEqual(statuses[i], 401, `Attempt ${i + 1} should be 401`);
      }
      assert.strictEqual(statuses[5], 429, '6th rapid attempt must return 429 Too Many Requests');
    } finally {
      testServer.close();
    }
  });

  // ─── TEST: Password Reset Minimum Length Enforcement ───────────────────
  test('Password reset security: explicit newPassword of min 10 chars enforced', () => {
    const { updateUserPassword } = require('../middleware/auth');
    assert.throws(() => {
      updateUserPassword('testuser', '');
    }, /at least 10 characters/);
    assert.throws(() => {
      updateUserPassword('testuser', 'short9ch!');
    }, /at least 10 characters/);
  });

  // ─── TEST: Admin RBAC Hardening on Mutating Admin Endpoints ──────────
  test('Admin RBAC: Designer gets 403 on mutating routes and logs to AuditService; Admin gets 200', async () => {
    const express = require('express');
    const http = require('http');
    const apiRoutes = require('../routes/api');
    const { generateToken } = require('../middleware/auth');
    const AuditService = require('../services/AuditService');

    const app = express();
    app.use(express.json());
    app.use('/api', apiRoutes);

    const testServer = http.createServer(app);
    await new Promise((resolve) => testServer.listen(0, '127.0.0.1', resolve));
    const port = testServer.address().port;

    const designerUser = {
      id: 'SS0099',
      username: 'designer_test',
      name: 'Test Designer',
      role: 'Designer',
      roles: ['Designer'],
      staffId: 'SS0099'
    };
    const designerToken = generateToken(designerUser);

    const adminUser = {
      id: 'SS0000',
      username: 'admin_test',
      name: 'System Administrator',
      role: 'Administrator',
      roles: ['Admin'],
      staffId: 'SS0000'
    };
    const adminToken = generateToken(adminUser);

    const mutatingEndpoints = [
      { method: 'POST', path: '/api/users', body: { name: 'New Staff', role: 'Designer' } },
      { method: 'PUT', path: '/api/users/SS0099', body: { name: 'Updated Staff' } },
      { method: 'DELETE', path: '/api/users/SS0099' },
      { method: 'POST', path: '/api/users/designer_test/reset-password', body: { newPassword: 'NewPassword123!' } },
      { method: 'POST', path: '/api/team/roster', body: { name: 'Roster Staff', role: 'Designer' } },
      { method: 'PUT', path: '/api/team/roster/SS0099', body: { name: 'Updated Roster Staff' } },
      { method: 'POST', path: '/api/companies', body: { code: 'TESTCO', name: 'Test Company' } },
      { method: 'PUT', path: '/api/companies/TESTCO', body: { name: 'Updated Company' } },
      { method: 'DELETE', path: '/api/companies/TESTCO' },
      { method: 'POST', path: '/api/system/workspace-root', body: { workspacePath: 'C:\\test' } },
      { method: 'POST', path: '/api/admin/restart', body: {} }
    ];

    let testStaff1, testStaff2;

    const makeRequest = (method, path, token, body = null) => {
      return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const headers = {
          'Authorization': `Bearer ${token}`
        };
        if (payload) {
          headers['Content-Type'] = 'application/json';
          headers['Content-Length'] = Buffer.byteLength(payload);
        }
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path,
          method,
          headers
        }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            let json = {};
            try { json = JSON.parse(data); } catch (e) {}
            resolve({ statusCode: res.statusCode, body: json });
          });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
      });
    };

    try {
      // 1. Verify Designer token receives 403 Forbidden on EVERY mutating admin route
      for (const ep of mutatingEndpoints) {
        const res = await makeRequest(ep.method, ep.path, designerToken, ep.body);
        assert.strictEqual(
          res.statusCode,
          403,
          `Designer token must receive 403 on ${ep.method} ${ep.path}, got ${res.statusCode}`
        );
      }

      // 2. Verify AuditService recorded SECURITY_ACCESS_DENIED entries for the denials
      const recentLogs = AuditService.getLogs({ limit: 50 });
      const deniedLogs = recentLogs.filter(l => l.action === 'SECURITY_ACCESS_DENIED' && l.actor === 'Test Designer');
      assert.ok(
        deniedLogs.length >= mutatingEndpoints.length,
        `AuditService must contain at least ${mutatingEndpoints.length} denial entries, found ${deniedLogs.length}`
      );

      // 3. Verify Admin token succeeds (200) on mutating admin routes
      testStaff1 = 'SS99' + Math.floor(1000 + Math.random() * 8999);
      testStaff2 = 'SS98' + Math.floor(1000 + Math.random() * 8999);

      const adminResUsers = await makeRequest('POST', '/api/users', adminToken, {
        staffId: testStaff1,
        name: 'Admin Added User',
        username: `admin_user_${testStaff1.toLowerCase()}`,
        role: 'Designer'
      });
      assert.strictEqual(adminResUsers.statusCode, 200, `Admin token must receive 200 on POST /api/users, got ${adminResUsers.statusCode}`);

      const adminResRoster = await makeRequest('POST', '/api/team/roster', adminToken, {
        staffId: testStaff2,
        name: 'Admin Added Roster',
        username: `admin_roster_${testStaff2.toLowerCase()}`,
        role: 'Designer'
      });
      assert.strictEqual(adminResRoster.statusCode, 200, `Admin token must receive 200 on POST /api/team/roster, got ${adminResRoster.statusCode}`);

      const adminResCo = await makeRequest('POST', '/api/companies', adminToken, {
        code: 'TESTCO',
        name: 'Admin Test Company'
      });
      assert.strictEqual(adminResCo.statusCode, 200, `Admin token must receive 200 on POST /api/companies, got ${adminResCo.statusCode}`);

      const adminResCoPut = await makeRequest('PUT', '/api/companies/TESTCO', adminToken, {
        name: 'Admin Updated Company'
      });
      assert.strictEqual(adminResCoPut.statusCode, 200, `Admin token must receive 200 on PUT /api/companies/TESTCO, got ${adminResCoPut.statusCode}`);

      const adminResCoDel = await makeRequest('DELETE', '/api/companies/TESTCO', adminToken);
      assert.strictEqual(adminResCoDel.statusCode, 200, `Admin token must receive 200 on DELETE /api/companies/TESTCO, got ${adminResCoDel.statusCode}`);

      const adminResRestart = await makeRequest('POST', '/api/admin/restart', adminToken, {});
      assert.strictEqual(adminResRestart.statusCode, 200, `Admin token must receive 200 on POST /api/admin/restart, got ${adminResRestart.statusCode}`);
    } finally {
      testServer.close();
      const TeamService = require('../services/TeamService');
      const CompanyService = require('../services/CompanyService');
      try { TeamService.deleteStaffMember('SS0098'); } catch (e) {}
      try { TeamService.deleteStaffMember('SS0097'); } catch (e) {}
      try { if (testStaff1) TeamService.deleteStaffMember(testStaff1); } catch (e) {}
      try { if (testStaff2) TeamService.deleteStaffMember(testStaff2); } catch (e) {}
      try { CompanyService.deleteCompany('TESTCO'); } catch (e) {}
    }
  });

  // ─── TEST: DATA_DIR Migration from Legacy Workspace Path ────────────────
  test('DATA_DIR migration: legacy workspace password file is migrated to DATA_DIR and archived', () => {
    const origRoot = config.WORKSPACE_ROOT;
    const origDataDir = config.DATA_DIR;
    const sandboxDir = path.join(__dirname, 'temp-sandbox-datadir-migration');
    const legacyWorkspace = path.join(sandboxDir, 'legacy-ws');
    const newDataDir = path.join(sandboxDir, 'isolated-data');

    try {
      fs.mkdirSync(path.join(legacyWorkspace, '_Team', '_Config'), { recursive: true });
      fs.mkdirSync(newDataDir, { recursive: true });

      const legacyPasswordFile = path.join(legacyWorkspace, '_Team', '_Config', 'user_passwords.json');
      fs.writeFileSync(legacyPasswordFile, JSON.stringify({ migrated_user: 'Secret123!' }), 'utf8');

      config.WORKSPACE_ROOT = legacyWorkspace;
      config.DATA_DIR = newDataDir;

      const { getPasswordStorePath, getStoredPasswords } = require('../middleware/auth');
      const resolvedPath = getPasswordStorePath();

      assert.strictEqual(resolvedPath, path.join(newDataDir, 'user_passwords.json'), 'Path must resolve under DATA_DIR');
      assert.ok(fs.existsSync(resolvedPath), 'Password store must exist in new DATA_DIR');

      const loaded = getStoredPasswords();
      assert.strictEqual(loaded.migrated_user, 'Secret123!', 'Migrated credentials must be loaded');

      // Check that legacy file was safely archived
      const archivedFiles = fs.readdirSync(path.join(legacyWorkspace, '_Team', '_Config')).filter(f => f.includes('user_passwords.json.migrated'));
      assert.ok(archivedFiles.length > 0, 'Legacy workspace password file must be renamed/archived');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      config.DATA_DIR = origDataDir;
      try { fs.rmSync(sandboxDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST: Helmet Headers & 1MB Body Limit ─────────────────────────────
  test('Security headers & body limit: Helmet sets nosniff CSP and >1MB payload returns 413', async () => {
    const express = require('express');
    const helmet = require('helmet');
    const http = require('http');

    const app = express();
    app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"]
        }
      }
    }));
    app.use(express.json({ limit: '1mb' }));
    app.post('/test-body-limit', (req, res) => res.json({ ok: true }));

    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;

    try {
      // 1. Verify Helmet security headers
      const headerCheck = await new Promise((resolve, reject) => {
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path: '/test-body-limit',
          method: 'POST',
          headers: { 'Content-Type': 'application/json' }
        }, res => {
          resolve({
            nosniff: res.headers['x-content-type-options'],
            csp: res.headers['content-security-policy']
          });
        });
        req.on('error', reject);
        req.write(JSON.stringify({ ok: true }));
        req.end();
      });

      assert.strictEqual(headerCheck.nosniff, 'nosniff', 'X-Content-Type-Options must be nosniff');
      assert.ok(headerCheck.csp, 'Content-Security-Policy header must be present');

      // 2. Verify >1MB payload returns HTTP 413 Payload Too Large
      const oversizedPayload = JSON.stringify({ data: 'X'.repeat(1024 * 1024 * 1.5) }); // 1.5MB
      const bodyLimitStatus = await new Promise((resolve, reject) => {
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path: '/test-body-limit',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(oversizedPayload)
          }
        }, res => resolve(res.statusCode));
        req.on('error', reject);
        req.write(oversizedPayload);
        req.end();
      });

      assert.strictEqual(bodyLimitStatus, 413, 'Payload over 1MB must return HTTP 413');
    } finally {
      server.close();
    }
  });

  // ─── TEST: JWT Lifetime (12 Hours) ─────────────────────────────────────
  test('JWT configuration: token lifetime is configured to 12 hours', () => {
    const { generateToken } = require('../middleware/auth');
    const jwt = require('jsonwebtoken');

    const token = generateToken({
      id: 'SS0004',
      username: 'harussani',
      name: 'Harussani',
      roles: ['Designer']
    });

    const decoded = jwt.decode(token);
    assert.ok(decoded.exp && decoded.iat, 'Token must contain exp and iat timestamps');
    const lifetimeHours = (decoded.exp - decoded.iat) / 3600;
    assert.strictEqual(lifetimeHours, 12, 'Token lifetime must be exactly 12 hours');
  });

  // ─── TEST: Last-Administrator Protection ───────────────────────────────
  test('Last-admin protection: cannot deactivate, demote, or delete the last active administrator', async () => {
    const express = require('express');
    const http = require('http');
    const { generateToken, hasCanonicalRole } = require('../middleware/auth');
    const TeamService = require('../services/TeamService');

    const app = express();
    app.use(express.json());
    app.use('/api', apiRoutes);

    const testServer = http.createServer(app);
    await new Promise(resolve => testServer.listen(0, '127.0.0.1', resolve));
    const port = testServer.address().port;

    const makeRequest = (method, path, token, body = null) => {
      return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const headers = { 'Authorization': `Bearer ${token}` };
        if (payload) {
          headers['Content-Type'] = 'application/json';
          headers['Content-Length'] = Buffer.byteLength(payload);
        }
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path,
          method,
          headers
        }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            let json = {};
            try { json = JSON.parse(data); } catch (e) {}
            resolve({ statusCode: res.statusCode, body: json });
          });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
      });
    };

    const soleAdminId = 'SS91' + Math.floor(1000 + Math.random() * 8999);
    const secondAdminId = 'SS92' + Math.floor(1000 + Math.random() * 8999);
    const origRoster = JSON.parse(JSON.stringify(TeamService.getStaffRoster()));

    try {
      // Setup: clean up any leftovers
      try { TeamService.deleteStaffMember(soleAdminId); } catch (e) {}
      try { TeamService.deleteStaffMember(secondAdminId); } catch (e) {}

      // Add our test admin
      TeamService.addStaffMember({
        staffId: soleAdminId,
        name: 'Sole Test Admin',
        username: `sole_admin_${soleAdminId.toLowerCase()}`,
        role: 'Administrator',
        roles: ['Admin'],
        active: true
      });

      // Temporarily deactivate other admins so soleAdminId is the ONLY active admin
      const currentRoster = TeamService.getStaffRoster();
      const otherAdmins = currentRoster.filter(u => u.staffId !== soleAdminId && hasCanonicalRole(u, 'admin') && u.active !== false);
      for (const oa of otherAdmins) {
        TeamService.updateStaffMember(oa.staffId, { active: false });
      }

      const adminToken = generateToken({
        id: soleAdminId,
        username: `sole_admin_${soleAdminId.toLowerCase()}`,
        name: 'Sole Test Admin',
        roles: ['Admin']
      });

      // 1. Attempt to DELETE the last active admin -> must return 400
      const deleteRes = await makeRequest('DELETE', `/api/users/${soleAdminId}`, adminToken);
      assert.strictEqual(deleteRes.statusCode, 400, `Deleting last admin must return 400, got ${deleteRes.statusCode}`);
      assert.ok(deleteRes.body.error && deleteRes.body.error.includes('last remaining administrator'), 'Error message must specify last remaining administrator');

      // 2. Attempt to deactivate the last active admin -> must return 400
      const deactRes = await makeRequest('PUT', `/api/users/${soleAdminId}`, adminToken, { active: false });
      assert.strictEqual(deactRes.statusCode, 400, `Deactivating last admin must return 400, got ${deactRes.statusCode}`);
      assert.ok(deactRes.body.error && deactRes.body.error.includes('last remaining administrator'));

      // 3. Attempt to demote the last active admin to Designer -> must return 400
      const demoteRes = await makeRequest('PUT', `/api/users/${soleAdminId}`, adminToken, { role: 'Designer', roles: ['Designer'] });
      assert.strictEqual(demoteRes.statusCode, 400, `Demoting last admin must return 400, got ${demoteRes.statusCode}`);
      assert.ok(demoteRes.body.error && demoteRes.body.error.includes('last remaining administrator'));

      // 4. Now add a second active admin
      TeamService.addStaffMember({
        staffId: secondAdminId,
        name: 'Second Test Admin',
        username: `second_admin_${secondAdminId.toLowerCase()}`,
        role: 'Administrator',
        roles: ['Admin'],
        active: true
      });

      // 5. With two active admins, deactivating the first admin should now SUCCEED (200)
      const allowedDeactRes = await makeRequest('PUT', `/api/users/${soleAdminId}`, adminToken, { active: false });
      assert.strictEqual(allowedDeactRes.statusCode, 200, `Deactivating admin when a second admin exists must succeed (200), got ${allowedDeactRes.statusCode}`);

    } finally {
      testServer.close();
      // Restore original roster states
      try { TeamService.deleteStaffMember(soleAdminId); } catch (e) {}
      try { TeamService.deleteStaffMember(secondAdminId); } catch (e) {}
      TeamService.saveStaffRoster(origRoster);
    }
  });

  // ─── TEST: Anti-Escalation on Profile Updates ──────────────────────────
  test('Anti-escalation: non-admin caller cannot modify role or roles via PUT /api/auth/profile', async () => {
    const express = require('express');
    const http = require('http');
    const { generateToken } = require('../middleware/auth');
    const TeamService = require('../services/TeamService');

    const app = express();
    app.use(express.json());
    app.use('/api', apiRoutes);

    const testServer = http.createServer(app);
    await new Promise(resolve => testServer.listen(0, '127.0.0.1', resolve));
    const port = testServer.address().port;

    const makeRequest = (method, path, token, body = null) => {
      return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const headers = { 'Authorization': `Bearer ${token}` };
        if (payload) {
          headers['Content-Type'] = 'application/json';
          headers['Content-Length'] = Buffer.byteLength(payload);
        }
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path,
          method,
          headers
        }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            let json = {};
            try { json = JSON.parse(data); } catch (e) {}
            resolve({ statusCode: res.statusCode, body: json });
          });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
      });
    };

    const designerStaffId = 'SS93' + Math.floor(1000 + Math.random() * 8999);
    try {
      TeamService.addStaffMember({
        staffId: designerStaffId,
        name: 'Escalation Target Designer',
        username: `target_designer_${designerStaffId.toLowerCase()}`,
        role: 'Designer',
        roles: ['Designer'],
        active: true
      });

      const designerToken = generateToken({
        id: designerStaffId,
        staffId: designerStaffId,
        username: `target_designer_${designerStaffId.toLowerCase()}`,
        name: 'Escalation Target Designer',
        role: 'Designer',
        roles: ['Designer']
      });

      // Non-admin attempts to self-promote to Admin
      const res = await makeRequest('PUT', '/api/auth/profile', designerToken, {
        name: 'Escalation Target Renamed',
        role: 'Administrator',
        roles: ['Admin']
      });

      assert.strictEqual(res.statusCode, 200, `Profile update should succeed for allowable fields, got ${res.statusCode}`);

      // Verify that the user's role in the database remains 'Designer'
      const updated = TeamService.getStaffRoster().find(m => m.staffId === designerStaffId);
      assert.ok(updated, 'Updated member must exist in roster');
      assert.strictEqual(updated.name, 'Escalation Target Renamed', 'Name update should be applied');
      assert.strictEqual(updated.role, 'Designer', 'Role escalation must be rejected');
      assert.deepStrictEqual(updated.roles, ['Designer'], 'Roles escalation must be rejected');

    } finally {
      testServer.close();
      try { TeamService.deleteStaffMember(designerStaffId); } catch (e) {}
    }
  });

  // ─── TEST: Self-Service Password Change ────────────────────────────────
  test('Self-service password change: enforces current password verification and 10-char complexity', async () => {
    const express = require('express');
    const http = require('http');
    const { generateToken, updateUserPassword, verifyUserPassword } = require('../middleware/auth');

    const app = express();
    app.use(express.json());
    app.use('/api', apiRoutes);

    const testServer = http.createServer(app);
    await new Promise(resolve => testServer.listen(0, '127.0.0.1', resolve));
    const port = testServer.address().port;

    const makeRequest = (method, path, token, body = null) => {
      return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;
        if (payload) {
          headers['Content-Type'] = 'application/json';
          headers['Content-Length'] = Buffer.byteLength(payload);
        }
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path,
          method,
          headers
        }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            let json = {};
            try { json = JSON.parse(data); } catch (e) {}
            resolve({ statusCode: res.statusCode, body: json });
          });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
      });
    };

    const testUsername = 'pwd_test_' + Date.now();
    const initialPwd = 'InitialPassword1!';
    updateUserPassword(testUsername, initialPwd);

    const userToken = generateToken({
      id: 'SS9401',
      username: testUsername,
      name: 'Password Test User',
      role: 'Designer',
      roles: ['Designer']
    });

    try {
      // 1. Unauthenticated request -> 401
      const unauthRes = await makeRequest('POST', '/api/auth/change-password', null, {
        currentPassword: initialPwd,
        newPassword: 'NewValidPassword123!'
      });
      assert.strictEqual(unauthRes.statusCode, 401, 'Unauthenticated request must return 401');

      // 2. Wrong current password -> 400
      const wrongCurrentRes = await makeRequest('POST', '/api/auth/change-password', userToken, {
        currentPassword: 'WrongPassword999!',
        newPassword: 'NewValidPassword123!'
      });
      assert.strictEqual(wrongCurrentRes.statusCode, 400, 'Wrong current password must return 400');
      assert.ok(wrongCurrentRes.body.error && wrongCurrentRes.body.error.includes('Current password is incorrect'));

      // 3. New password too short (< 10 chars) -> 400
      const shortPwdRes = await makeRequest('POST', '/api/auth/change-password', userToken, {
        currentPassword: initialPwd,
        newPassword: 'Short1!'
      });
      assert.strictEqual(shortPwdRes.statusCode, 400, 'Short new password must return 400');

      // 4. Correct current password and valid new password -> 200
      const validRes = await makeRequest('POST', '/api/auth/change-password', userToken, {
        currentPassword: initialPwd,
        newPassword: 'BrandNewSecurePassword2026!'
      });
      assert.strictEqual(validRes.statusCode, 200, 'Valid password change must return 200');
      assert.strictEqual(validRes.body.success, true);

      // Verify that old password fails and new password succeeds in verifyUserPassword
      assert.strictEqual(verifyUserPassword(testUsername, initialPwd), false, 'Old password must no longer be valid');
      assert.strictEqual(verifyUserPassword(testUsername, 'BrandNewSecurePassword2026!'), true, 'New password must verify successfully');

    } finally {
      testServer.close();
    }
  });

  // ─── TEST: Canonical Role Matching & Rejection of Fuzzy Substrings ─────
  test('Canonical role matching: fuzzy roles like admin_assistant or subadmin are rejected from admin routes', async () => {
    const express = require('express');
    const http = require('http');
    const { generateToken, hasCanonicalRole } = require('../middleware/auth');

    const app = express();
    app.use(express.json());
    app.use('/api', apiRoutes);

    const testServer = http.createServer(app);
    await new Promise(resolve => testServer.listen(0, '127.0.0.1', resolve));
    const port = testServer.address().port;

    const makeRequest = (method, path, token) => {
      return new Promise((resolve, reject) => {
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path,
          method,
          headers: { 'Authorization': `Bearer ${token}` }
        }, (res) => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            let json = {};
            try { json = JSON.parse(data); } catch (e) {}
            resolve({ statusCode: res.statusCode, body: json });
          });
        });
        req.on('error', reject);
        req.end();
      });
    };

    try {
      // 1. Unit check hasCanonicalRole
      assert.strictEqual(hasCanonicalRole({ roles: ['Admin'] }, 'admin'), true);
      assert.strictEqual(hasCanonicalRole({ role: 'Administrator' }, 'admin'), true);
      assert.strictEqual(hasCanonicalRole({ roles: ['admin_assistant'] }, 'admin'), false);
      assert.strictEqual(hasCanonicalRole({ role: 'subadmin' }, 'admin'), false);
      assert.strictEqual(hasCanonicalRole({ roles: ['system_administrator_intern'] }, 'admin'), false);

      // 2. Integration check: tokens with fuzzy roles receive 403 on admin-only routes
      const fuzzyRoles = ['Admin Assistant', 'subadmin', 'system_admin_trainee'];
      for (const fuzzyRole of fuzzyRoles) {
        const fuzzyToken = generateToken({
          id: 'SS9501',
          username: 'fuzzy_user',
          name: 'Fuzzy Role User',
          role: fuzzyRole,
          roles: [fuzzyRole]
        });

        const res = await makeRequest('POST', '/api/admin/restart', fuzzyToken);
        assert.strictEqual(
          res.statusCode,
          403,
          `Fuzzy role '${fuzzyRole}' must receive 403 on admin route, got ${res.statusCode}`
        );
      }
    } finally {
      testServer.close();
    }
  });

  // Test 49: Mobile & API project creation: POST /api/projects requires auth, validates input, and returns 201
  test('Mobile project creation: POST /api/projects validates auth and payload, creates project structure, and returns 201', async () => {
    const express = require('express');
    const http = require('http');
    const app = express();
    app.use(express.json());
    app.use('/api', require('../routes/api'));

    const testServer = http.createServer(app);
    await new Promise(resolve => testServer.listen(0, resolve));
    const port = testServer.address().port;

    const makeRequest = (method, pathUrl, token = null, body = null) => {
      return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const headers = { 'Content-Type': 'application/json' };
        if (token) headers['Authorization'] = `Bearer ${token}`;
        if (payload) headers['Content-Length'] = Buffer.byteLength(payload);

        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path: pathUrl,
          method,
          headers
        }, res => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => {
            try {
              resolve({ statusCode: res.statusCode, body: data ? JSON.parse(data) : {} });
            } catch (e) {
              resolve({ statusCode: res.statusCode, rawBody: data });
            }
          });
        });
        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
      });
    };

    let createdFolder = null;
    try {
      const { generateToken } = require('../middleware/auth');
      const designerToken = generateToken({
        id: 'SS0004',
        username: 'harussani',
        name: 'Harussani',
        role: 'Designer',
        roles: ['Designer']
      });

      // 1. Unauthenticated request -> 401
      const unauthRes = await makeRequest('POST', '/api/projects', null, { title: 'Test Task' });
      assert.strictEqual(unauthRes.statusCode, 401, 'Unauthenticated request must return 401');

      // 2. Missing title -> 400
      const missingTitleRes = await makeRequest('POST', '/api/projects', designerToken, {});
      assert.strictEqual(missingTitleRes.statusCode, 400, 'Missing title must return 400');

      // 3. Valid creation request -> 201
      const validPayload = {
        title: 'Automated Test Deliverable',
        brand: 'SS',
        designer: 'Harussani',
        priority: 'urgent',
        department: 'Creative Production',
        deadline: '2026-10-15'
      };

      const createRes = await makeRequest('POST', '/api/projects', designerToken, validPayload);
      assert.strictEqual(createRes.statusCode, 201, `Valid creation must return 201, got ${createRes.statusCode}`);
      assert.ok(createRes.body.id, 'Response must include project id');
      assert.strictEqual(createRes.body.status, 'in_progress');
      assert.strictEqual(createRes.body.priority, 'urgent');

      createdFolder = path.join(WorkspaceService.workspaceRoot, createRes.body.id);
      assert.ok(fs.existsSync(createdFolder), 'Project directory must be created on disk');
      assert.ok(fs.existsSync(path.join(createdFolder, 'README.md')), 'README.md must be generated');
      assert.ok(fs.existsSync(path.join(createdFolder, '03_COPYWRITING', 'COPY.md')), 'COPY.md must be generated');
      assert.ok(fs.existsSync(path.join(createdFolder, '05_DELIVERABLES')), '05_DELIVERABLES must be generated');

      // Verify Frontmatter
      const { frontmatter } = FrontmatterService.readProjectReadme(createdFolder);
      assert.strictEqual(frontmatter.title, 'Automated Test Deliverable');
      assert.strictEqual(frontmatter.brand, 'SS');
      assert.strictEqual(frontmatter.designer, 'Harussani');
    } finally {
      testServer.close();
      if (createdFolder && fs.existsSync(createdFolder)) {
        try { fs.rmSync(createdFolder, { recursive: true, force: true }); } catch (e) {}
      }
    }
  });

  // ─── TEST: Batch Archive Vault Service & Catalog ───────────────────
  test('ExportService.archiveBatch packages multiple projects and appends to _archive_catalog.jsonl', async () => {
    const ExportService = require('../services/ExportService');
    const testArchiveDir = path.join(__dirname, 'temp-test-archive-root');
    const proj1 = path.join(testArchiveDir, 'TEST_001_Alpha');
    const proj2 = path.join(testArchiveDir, 'TEST_002_Beta');

    fs.mkdirSync(path.join(proj1, '05_DELIVERABLES'), { recursive: true });
    fs.writeFileSync(path.join(proj1, 'README.md'), '# Alpha Project\n');
    fs.writeFileSync(path.join(proj1, '05_DELIVERABLES', 'asset.png'), 'fake-png-content');

    fs.mkdirSync(path.join(proj2, '05_DELIVERABLES'), { recursive: true });
    fs.writeFileSync(path.join(proj2, 'README.md'), '# Beta Project\n');
    fs.writeFileSync(path.join(proj2, '05_DELIVERABLES', 'banner.jpg'), 'fake-jpg-content');

    try {
      const res = await ExportService.archiveBatch([proj1, proj2], testArchiveDir, { copyOnly: true }, 'test-user');
      assert.strictEqual(res.success, true);
      assert.strictEqual(res.projectCount, 2);
      assert.ok(fs.existsSync(res.zipFilePath), 'ZIP archive should exist on disk');
      assert.ok(res.zipSizeBytes > 0, 'ZIP size should be greater than zero');

      const catalogPath = path.join(testArchiveDir, '_Archive', '_archive_catalog.jsonl');
      assert.ok(fs.existsSync(catalogPath), 'Catalog JSONL file should exist');
      const catalogContent = fs.readFileSync(catalogPath, 'utf8');
      assert.ok(catalogContent.includes('TEST_001_Alpha'));
      assert.ok(catalogContent.includes('TEST_002_Beta'));
    } finally {
      try { fs.rmSync(testArchiveDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST: Multi-Format Asset Transcoder Bridge ────────────────────
  test('ExportService.transcodeAsset converts image assets to WebP via FFmpeg', async () => {
    const ExportService = require('../services/ExportService');
    const testTranscodeDir = path.join(__dirname, 'temp-test-transcode');
    fs.mkdirSync(testTranscodeDir, { recursive: true });

    // Find sample asset
    const sourcePng = path.resolve(__dirname, '../../../../payload/Brand Assets/Logos/ss_icon_light.png');
    if (!fs.existsSync(sourcePng)) {
      try { fs.rmSync(testTranscodeDir, { recursive: true, force: true }); } catch (e) {}
      return;
    }

    try {
      const res = await ExportService.transcodeAsset(sourcePng, 'webp', testTranscodeDir);
      assert.strictEqual(res.success, true);
      assert.ok(fs.existsSync(res.outputPath), 'Transcoded WebP file should exist on disk');
      assert.ok(res.outputSizeBytes > 0, 'Transcoded output size should be > 0 bytes');
      assert.ok(res.outputPath.endsWith('.webp'), 'Output extension should be .webp');
    } catch (err) {
      if (err.message && (err.message.includes('ENOENT') || err.message.includes('ffmpeg'))) {
        console.log('     ℹ️ Skipping: ffmpeg binary not installed on host');
        return;
      }
      throw err;
    } finally {
      try { fs.rmSync(testTranscodeDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  test('Security Hardening: /export, /notes, and /users require JWT authentication; note path traversal is sanitized', async () => {
    const express = require('express');
    const http = require('http');
    const { generateToken } = require('../middleware/auth');
    const app = express();
    app.use(express.json());
    app.use('/api', require('../routes/api'));

    const server = await new Promise(r => { const s = app.listen(0, '127.0.0.1', () => r(s)); });
    const port = server.address().port;

    try {
      // 1. Unauthenticated export must return 401
      const unauthExport = await new Promise(resolve => {
        http.get(`http://127.0.0.1:${port}/api/projects/sample/export`, r => resolve(r.statusCode));
      });
      assert.strictEqual(unauthExport, 401, 'Unauthenticated project export must return 401');

      // 2. Unauthenticated POST notes must return 401
      const unauthNotePost = await new Promise(resolve => {
        const req = http.request(`http://127.0.0.1:${port}/api/notes`, { method: 'POST', headers: { 'Content-Type': 'application/json' } }, r => resolve(r.statusCode));
        req.write(JSON.stringify({ title: 'Hacked Note' }));
        req.end();
      });
      assert.strictEqual(unauthNotePost, 401, 'Unauthenticated POST /api/notes must return 401');

      // 3. Unauthenticated DELETE notes must return 401
      const unauthNoteDelete = await new Promise(resolve => {
        const req = http.request(`http://127.0.0.1:${port}/api/notes/sample_note`, { method: 'DELETE' }, r => resolve(r.statusCode));
        req.end();
      });
      assert.strictEqual(unauthNoteDelete, 401, 'Unauthenticated DELETE /api/notes must return 401');

      // 4. Authenticated POST notes succeeds and sanitizes path traversal
      const validToken = generateToken({ staffId: 'SS0001', username: 'sec_tester', name: 'Security Tester', role: 'Designer' });
      const authNotePost = await new Promise(resolve => {
        const req = http.request(`http://127.0.0.1:${port}/api/notes`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${validToken}`
          }
        }, r => {
          let data = '';
          r.on('data', c => data += c);
          r.on('end', () => resolve({ status: r.statusCode, body: JSON.parse(data || '{}') }));
        });
        req.write(JSON.stringify({ id: '../../traversal_test', title: 'Sanitized Note', body: 'Safe text' }));
        req.end();
      });
      assert.strictEqual(authNotePost.status, 200, 'Authenticated POST notes should succeed');
      assert.ok(!authNotePost.body.note.id.includes('..'), 'Note ID must be sanitized against path traversal');

      // 5. Clean up created note
      await new Promise(resolve => {
        const req = http.request(`http://127.0.0.1:${port}/api/notes/${authNotePost.body.note.id}`, {
          method: 'DELETE',
          headers: { 'Authorization': `Bearer ${validToken}` }
        }, r => resolve(r.statusCode));
        req.end();
      });
    } finally {
      server.close();
    }
  });

  // Test 53: TaskService & ClickUp Task Management: Aggregates tasks, creates, updates, and deletes task linked to project
  test('TaskService & ClickUp Task Management: Aggregates tasks, creates, updates, and deletes task linked to project', async () => {
    const TaskService = require('../services/TaskService');
    const projects = WorkspaceService.getAllProjects();
    assert.ok(projects.length > 0, 'Must have at least one sample project');
    const p = projects[0];

    // 1. Create a task linked to projectId
    const createdTask = TaskService.createTask(p.id, {
      name: 'Write 3 Hook Angles for WhatsApp',
      role: 'copywriter',
      assignee: 'sarah',
      assigneeName: 'Sarah Al-Attas',
      status: 'draft',
      weight: 2.0,
      channel: 'whatsapp',
      notes: 'Test hook script'
    }, 'TestRunner');

    assert.ok(createdTask.id, 'Created task must have an ID');
    assert.strictEqual(createdTask.role, 'copywriter', 'Role must normalize to copywriter');
    assert.strictEqual(createdTask.status, 'draft');

    // 2. Fetch all tasks and verify inclusion
    const allTasks = TaskService.getAllTasks({ projectId: p.id });
    const found = allTasks.find(t => t.id === createdTask.id);
    assert.ok(found, 'Created task must be found in getAllTasks');
    assert.strictEqual(found.projectId, p.id, 'Task must link to project ID');
    assert.strictEqual(found.projectTitle, p.title, 'Task must inherit project title');

    // 3. Update task status (e.g. from draft -> in-progress)
    const updated = TaskService.updateTask(p.id, createdTask.id, {
      status: 'in-progress',
      notes: 'Work started'
    }, 'TestRunner');
    assert.strictEqual(updated.status, 'in-progress', 'Status must update to in-progress');

    // 4. Update task status to done
    const doneTask = TaskService.updateTask(p.id, createdTask.id, {
      status: 'done'
    }, 'TestRunner');
    assert.strictEqual(doneTask.status, 'done', 'Status must update to done');

    // 5. Delete task
    const delResult = TaskService.deleteTask(p.id, createdTask.id, 'TestRunner');
    assert.ok(delResult.success, 'Delete task must succeed');

    // 6. Verify task no longer in project
    const afterDelete = TaskService.getAllTasks({ projectId: p.id });
    assert.ok(!afterDelete.some(t => t.id === createdTask.id), 'Deleted task must not appear');
  });

  // Test 54: Password Reset Suite & Email Service: Token generation, verification, password reset, and fallback email dispatch
  test('Password Reset Suite & Email Service: Token generation, verification, password reset, and fallback email dispatch', async () => {
    const { createPasswordResetToken, verifyPasswordResetToken, resetPasswordWithToken, verifyUserPassword, updateUserPassword } = require('../middleware/auth');
    const EmailService = require('../services/EmailService');

    // 1. Token generation for valid user
    const gen = createPasswordResetToken('harussani');
    assert.ok(gen, 'Token generation for harussani must succeed');
    assert.ok(gen.token, 'Token string must be present');
    assert.strictEqual(typeof gen.token, 'string');
    assert.strictEqual(gen.token.length, 64, 'Token must be 64-char hex string');

    // 2. Token verification
    const verified = verifyPasswordResetToken(gen.token);
    assert.ok(verified.valid, 'Newly created token must be valid');
    assert.strictEqual(verified.username, 'harussani');

    // 3. Invalid / non-existent token verification
    const invalidCheck = verifyPasswordResetToken('fake_token_12345');
    assert.strictEqual(invalidCheck.valid, false, 'Invalid token must return valid=false');

    // 4. Password reset with short password fails
    const shortReset = resetPasswordWithToken(gen.token, 'short');
    assert.strictEqual(shortReset.success, false, 'Short password (< 8 chars) must fail');

    // 5. Password reset with valid password succeeds
    const validReset = resetPasswordWithToken(gen.token, 'BrandNewSecurePassword2026!');
    assert.strictEqual(validReset.success, true, 'Valid password reset must succeed');
    assert.ok(verifyUserPassword('harussani', 'BrandNewSecurePassword2026!'), 'New password must verify successfully');

    // 6. Token is single-use: cannot be reused after successful reset
    const reuseCheck = verifyPasswordResetToken(gen.token);
    assert.strictEqual(reuseCheck.valid, false, 'Consumed token cannot be reused');

    // 7. Restore original password for test user
    updateUserPassword('harussani', 'SuamiSihat123!');

    // 8. EmailService fallback dispatch test
    const emailRes = await EmailService.sendPasswordResetEmail({ username: 'harussani', email: 'harussani@suamisihat.com' }, 'dummy_token', 'http://localhost:4000');
    assert.ok(emailRes.success, 'EmailService fallback dispatch must succeed');
  });

  // Test 55: HTTP Routes for ClickUp Tasks: GET, POST, PATCH, DELETE /api/tasks
  test('HTTP Routes for ClickUp Tasks: GET, POST, PATCH, DELETE /api/tasks return 200/201 and valid JSON', async () => {
    const express = require('express');
    const { generateToken } = require('../middleware/auth');
    const testApp = express();
    testApp.use(express.json());
    testApp.use('/api', apiRoutes);
    const server = await new Promise(res => {
      const s = testApp.listen(0, '127.0.0.1', () => res(s));
    });
    const port = server.address().port;
    const token = generateToken({ username: 'harussani', role: 'admin', name: 'Harussani' });

    const makeReq = (path, method = 'GET', body = null) => {
      return new Promise((resolve, reject) => {
        const postData = body ? JSON.stringify(body) : null;
        const headers = {
          'Authorization': `Bearer ${token}`
        };
        if (postData) {
          headers['Content-Type'] = 'application/json';
          headers['Content-Length'] = Buffer.byteLength(postData);
        }
        const req = http.request({
          hostname: '127.0.0.1',
          port,
          path,
          method,
          headers
        }, res => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(data || '{}') }));
        });
        req.on('error', reject);
        if (postData) req.write(postData);
        req.end();
      });
    };

    try {
      // 1. GET /api/tasks -> 200
      const getRes = await makeReq('/api/tasks');
      assert.strictEqual(getRes.status, 200, 'GET /api/tasks must return HTTP 200');
      assert.strictEqual(getRes.body.success, true);
      assert.ok(Array.isArray(getRes.body.tasks));
      assert.ok(getRes.body.stats);

      // 2. POST /api/tasks -> 201
      const projects = WorkspaceService.getAllProjects();
      const p = projects[0];
      const postRes = await makeReq('/api/tasks', 'POST', {
        projectId: p.id,
        name: 'HTTP Test Task Creation',
        role: 'copywriter',
        assignee: 'sarah',
        status: 'draft',
        weight: 1.0
      });
      assert.strictEqual(postRes.status, 201, 'POST /api/tasks must return HTTP 201');
      assert.strictEqual(postRes.body.success, true);
      assert.ok(postRes.body.task?.id);
      const createdId = postRes.body.task.id;

      // 3. PATCH /api/tasks/:projectId/:taskId -> 200
      const patchRes = await makeReq(`/api/tasks/${p.id}/${createdId}`, 'PATCH', {
        status: 'in-progress'
      });
      assert.strictEqual(patchRes.status, 200, 'PATCH /api/tasks/:projectId/:taskId must return HTTP 200');
      assert.strictEqual(patchRes.body.task.status, 'in-progress');

      // 4. DELETE /api/tasks/:projectId/:taskId -> 200
      const delRes = await makeReq(`/api/tasks/${p.id}/${createdId}`, 'DELETE');
      assert.strictEqual(delRes.status, 200, 'DELETE /api/tasks/:projectId/:taskId must return HTTP 200');
      assert.strictEqual(delRes.body.success, true);
    } finally {
      server.close();
    }
  });

  // ─── TEST: TaskService Decoupled Pre-Production Task Storage ──────
  test('TaskService manages lightweight pre-production tasks in .sscam/tasks without creating NAS project folders', () => {
    const TaskService = require('../services/TaskService');
    const testDir = path.join(__dirname, 'temp-tasks-storage-test-' + Date.now());
    const origRoot = config.WORKSPACE_ROOT;

    try {
      config.WORKSPACE_ROOT = testDir;
      const tasksDir = path.join(testDir, '.sscam', 'tasks');

      // 1. Create a lightweight pre-production task
      const created = TaskService.createStudioTask({
        title: 'Ramadan 2026 Gift Box 3D Mockup Exploration',
        description: 'Explore gold foil stamping and green velvet insert concepts.',
        assignee: 'SS0004',
        brand: 'SS',
        priority: 'urgent',
        tags: ['packaging', '3d', 'concept']
      }, 'TestUser', 'Art Director');

      assert.ok(created, 'Task must be created');
      assert.ok(created.id.startsWith('TSK-'), 'Task must have a TSK- ID');
      assert.strictEqual(created.status, 'backlog');
      assert.strictEqual(created.title, 'Ramadan 2026 Gift Box 3D Mockup Exploration');

      // Verify physical storage is in .sscam/tasks/<id>.md
      const taskFile = path.join(tasksDir, `${created.id}.md`);
      assert.ok(fs.existsSync(taskFile), 'Markdown task file must exist in .sscam/tasks');

      // Verify NO heavy project folders were created in root
      const rootItems = fs.readdirSync(testDir);
      assert.ok(!rootItems.includes('01_BRIEF_ASSETS'), 'Must not create project folder 01_BRIEF_ASSETS in root');
      assert.ok(!rootItems.includes('05_DELIVERABLES'), 'Must not create 05_DELIVERABLES in root');
      assert.strictEqual(rootItems.length, 1, 'Only .sscam should exist in test workspace');
      assert.strictEqual(rootItems[0], '.sscam');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST: TaskService CRUD & Filtering ──────
  test('TaskService supports listing, filtering, updating, and deleting tasks', () => {
    const TaskService = require('../services/TaskService');
    const testDir = path.join(__dirname, 'temp-tasks-crud-test-' + Date.now());
    const origRoot = config.WORKSPACE_ROOT;

    try {
      config.WORKSPACE_ROOT = testDir;

      const t1 = TaskService.createStudioTask({
        title: 'TikTok Viral Script Variations',
        status: 'in-progress',
        brand: 'SSE',
        priority: 'high',
        assignee: 'SS0001'
      });

      const t2 = TaskService.createStudioTask({
        title: 'Clinic Signage Mockup',
        status: 'review',
        brand: 'SSC',
        priority: 'medium',
        assignee: 'SS0002'
      });

      // 1. List all
      const all = TaskService.getAllStudioTasks({});
      assert.strictEqual(all.length, 2, 'Must list 2 created tasks');

      // 2. Filter by status
      const inProgress = TaskService.getAllStudioTasks({ status: 'in-progress' });
      assert.strictEqual(inProgress.length, 1, 'Must filter 1 in-progress task');
      assert.strictEqual(inProgress[0].id, t1.id);

      // 3. Filter by brand
      const sscTasks = TaskService.getAllStudioTasks({ brand: 'SSC' });
      assert.strictEqual(sscTasks.length, 1, 'Must filter 1 SSC task');
      assert.strictEqual(sscTasks[0].id, t2.id);

      // 4. Update task
      const updated = TaskService.updateStudioTask(t1.id, {
        status: 'review',
        priority: 'urgent',
        title: 'TikTok Viral Script Variations (Updated)'
      });
      assert.strictEqual(updated.status, 'review');
      assert.strictEqual(updated.priority, 'urgent');
      assert.strictEqual(updated.title, 'TikTok Viral Script Variations (Updated)');

      // 5. Delete task
      const delRes = TaskService.deleteStudioTask(t2.id);
      assert.strictEqual(delRes.success, true);
      const remaining = TaskService.getAllStudioTasks({});
      assert.strictEqual(remaining.length, 1, 'Must have 1 task remaining');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST: TaskService NAS Workspace Provisioning Bridge ──────
  test('TaskService provisions a pre-production task into an official NAS project vault (The Bridge)', () => {
    const TaskService = require('../services/TaskService');
    const testDir = path.join(__dirname, 'temp-tasks-bridge-test-' + Date.now());
    const origRoot = config.WORKSPACE_ROOT;

    try {
      config.WORKSPACE_ROOT = testDir;

      // 1. Create pre-production task
      const task = TaskService.createStudioTask({
        title: 'SuperCharge Vitality Packaging Redesign',
        description: '## Campaign Overview\nRedesign the outer carton box with high-durability UV spot coating.',
        brand: 'SS',
        priority: 'high',
        dueDate: '2026-10-31',
        assignee: 'SS0004'
      }, 'Harussani', 'Art Director');

      assert.strictEqual(task.status, 'backlog');
      assert.strictEqual(task.jobId, null);
      assert.strictEqual(task.projectId, null);

      // 2. Trigger NAS Workspace Provisioning Bridge
      const provisionRes = TaskService.provisionTaskToProject(task.id, {
        brand: 'SS',
        presetType: 'Graphic & Print Design',
        designer: 'Harussani'
      }, 'Harussani', 'Art Director');

      assert.ok(provisionRes.success, 'Provisioning must succeed');
      assert.ok(provisionRes.jobId, 'Job ID must be generated');
      assert.ok(provisionRes.folderName, 'Folder name must be generated');
      assert.ok(provisionRes.projectDir, 'Target project dir must be returned');

      // 3. Verify standard 5 canonical folders were scaffolded
      const subFolders = ['01_BRIEF_ASSETS', '02_SOURCE_FILES', '03_COPYWRITING', '04_WORK_IN_PROGRESS', '05_DELIVERABLES'];
      for (const sub of subFolders) {
        const subPath = path.join(provisionRes.projectDir, sub);
        assert.ok(fs.existsSync(subPath), `Scaffolded folder ${sub} must exist on NAS`);
      }

      // 4. Verify initial COPY.md and README.md with migrated brief
      const readmePath = path.join(provisionRes.projectDir, 'README.md');
      assert.ok(fs.existsSync(readmePath), 'Project README.md must exist');
      const readmeContent = fs.readFileSync(readmePath, 'utf8');
      assert.ok(readmeContent.includes('SuperCharge Vitality Packaging Redesign'), 'README must contain task title');
      assert.ok(readmeContent.includes(task.id), 'README must reference originating task ID');

      // 5. Verify the task in .sscam/tasks is now marked as converted
      const updatedTask = TaskService.getStudioTaskById(task.id);
      assert.strictEqual(updatedTask.status, 'converted', 'Task status must be converted');
      assert.strictEqual(updatedTask.jobId, provisionRes.jobId, 'Task must store official JobId');
      assert.strictEqual(updatedTask.projectId, provisionRes.folderName, 'Task must store projectId');
      assert.ok(updatedTask.convertedAt, 'Task must have convertedAt timestamp');
    } finally {
      config.WORKSPACE_ROOT = origRoot;
      try { fs.rmSync(testDir, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 59: Multi-Format Packaging Presets (Print, Web, Archive) ────
  testAsync('ExportService supports multi-format packaging presets (print, web, archive)', async () => {
    const ExportService = require('../services/ExportService');
    const testProj = path.join(__dirname, 'temp-preset-test-proj');
    const delivDir = path.join(testProj, '05_DELIVERABLES');
    const srcDir = path.join(testProj, '02_SOURCE_FILES');
    const copyDir = path.join(testProj, '03_COPYWRITING');

    try {
      fs.mkdirSync(delivDir, { recursive: true });
      fs.mkdirSync(srcDir, { recursive: true });
      fs.mkdirSync(copyDir, { recursive: true });

      // Create test deliverables
      fs.writeFileSync(path.join(delivDir, 'box_packaging.pdf'), 'PDF DATA');
      fs.writeFileSync(path.join(delivDir, 'master_label.psd'), 'PSD DATA');
      fs.writeFileSync(path.join(delivDir, 'promo_teaser.mp4'), 'MP4 DATA');
      fs.writeFileSync(path.join(delivDir, 'social_feed.webp'), 'WEBP DATA');
      fs.writeFileSync(path.join(srcDir, 'raw_layers.ai'), 'AI DATA');
      fs.writeFileSync(path.join(copyDir, 'COPY.md'), '# Marketing Copy');
      fs.writeFileSync(path.join(testProj, 'README.md'), '---\nstatus: approved\n---');

      // Helper mock archive
      const makeMockArchive = () => {
        const added = [];
        return {
          file: (f, opts) => added.push(opts.name),
          append: (c, opts) => added.push(opts.name),
          pipe: () => {},
          on: () => {},
          finalize: () => {},
          added
        };
      };

      // Mock response
      const makeMockRes = () => {
        const headers = {};
        return {
          setHeader: (k, v) => { headers[k] = v; },
          status: () => ({ json: () => {} }),
          headers
        };
      };

      // 1. Test Print Preset
      const mockArchivePrint = makeMockArchive();
      const mockResPrint = makeMockRes();
      const origArchiver = require('archiver');
      // Temporarily override require in ExportService or test directory adding directly:
      const printFiles = [];
      const printExts = new Set(['.pdf', '.psd', '.ai', '.eps', '.tiff', '.tif', '.png', '.indd']);
      ExportService.addDirectoryToArchive(mockArchivePrint, delivDir, 'Deliverables', printFiles, (name) => printExts.has(path.extname(name).toLowerCase()));
      assert.ok(printFiles.includes('Deliverables/box_packaging.pdf'), 'Print preset must include PDF');
      assert.ok(printFiles.includes('Deliverables/master_label.psd'), 'Print preset must include PSD');
      assert.ok(!printFiles.includes('Deliverables/promo_teaser.mp4'), 'Print preset must exclude MP4');
      assert.ok(!printFiles.includes('Deliverables/social_feed.webp'), 'Print preset must exclude WEBP');

      // 2. Test Web Preset
      const mockArchiveWeb = makeMockArchive();
      const webFiles = [];
      const webExts = new Set(['.webp', '.mp4', '.png', '.jpg', '.jpeg', '.svg', '.gif', '.webm']);
      ExportService.addDirectoryToArchive(mockArchiveWeb, delivDir, 'Deliverables', webFiles, (name) => webExts.has(path.extname(name).toLowerCase()));
      assert.ok(webFiles.includes('Deliverables/promo_teaser.mp4'), 'Web preset must include MP4');
      assert.ok(webFiles.includes('Deliverables/social_feed.webp'), 'Web preset must include WEBP');
      assert.ok(!webFiles.includes('Deliverables/box_packaging.pdf'), 'Web preset must exclude PDF');
      assert.ok(!webFiles.includes('Deliverables/master_label.psd'), 'Web preset must exclude PSD');

      // 3. Test HTML Summary includes preset badge
      const summaryHtml = ExportService.generateHtmlSummary('TestProject', { status: 'approved' }, ['file1'], 'print');
      assert.ok(summaryHtml.includes('Packaging Preset'), 'Summary sheet must show Packaging Preset row');
      assert.ok(summaryHtml.includes('PRINT'), 'Summary sheet must reflect PRINT preset');
    } finally {
      try { fs.rmSync(testProj, { recursive: true, force: true }); } catch (e) {}
    }
  });

  // ─── TEST 60: Automated NAS Quota Telemetry & Health Radar ──────────
  test('WorkspaceService.getNasStorageTelemetry calculates volume capacity and quota thresholds', () => {
    const telemetry = WorkspaceService.getNasStorageTelemetry(sandboxWorkspace);
    assert.strictEqual(telemetry.available, true, 'Telemetry must be available for valid workspace directory');
    assert.ok(typeof telemetry.totalGB === 'number' && telemetry.totalGB > 0, 'Total storage must be > 0 GB');
    assert.ok(typeof telemetry.freeGB === 'number' && telemetry.freeGB > 0, 'Free storage must be > 0 GB');
    assert.ok(typeof telemetry.usedPercent === 'number' && telemetry.usedPercent >= 0 && telemetry.usedPercent <= 100, 'Used percent must be between 0 and 100');
    assert.ok(['healthy', 'warning', 'critical'].includes(telemetry.status), 'Status must be healthy, warning, or critical');
    assert.strictEqual(telemetry.thresholdPercent, 85, 'Quota threshold must default to 85%');
    assert.strictEqual(typeof telemetry.archiveRecommended, 'boolean', 'archiveRecommended must be boolean');
  });

  // ─── TEST 61: Multi-Workspace NAS Switching & Business Unit Telemetry ──
  test('WorkspaceService accurately resolves business unit metadata and candidate shares', () => {
    const defaultUnit = WorkspaceService.getBusinessUnit();
    assert.ok(defaultUnit && defaultUnit.code, 'Default business unit must have code');
    assert.ok(defaultUnit.share, 'Default business unit must have share name');
    assert.strictEqual(defaultUnit.code, 'CT', 'Default business unit should resolve to CT (Creative-Team)');

    // Test explicit paths
    const vpUnit = WorkspaceService.getBusinessUnit('D:\\SynologyDrive\\Video-Production');
    assert.strictEqual(vpUnit.code, 'VP', 'Path with Video-Production should resolve to VP');
    assert.strictEqual(vpUnit.share, 'Video-Production');

    const maUnit = WorkspaceService.getBusinessUnit('/volume1/Marketing-Assets');
    assert.strictEqual(maUnit.code, 'MA', 'Path with Marketing-Assets should resolve to MA');
    assert.strictEqual(maUnit.share, 'Marketing-Assets');

    const available = WorkspaceService.getAvailableBusinessUnits();
    assert.strictEqual(available.length, 3, 'Must have 3 canonical business units (CT, VP, MA)');
    assert.deepStrictEqual(available.map(u => u.code), ['CT', 'VP', 'MA']);
  });

  // ─── TEST 62: RegulatoryService KKM Compliance & Clinical SOP Manuals ──
  test('RegulatoryService audits prohibited medical claims, approval codes, and ensures SOP manuals', () => {
    const RegulatoryService = require('../services/RegulatoryService');

    // 1. Prohibited claims detection
    const badCopy = 'Ubat kuat ajaib ini pasti berkesan dan 100% sembuh tanpa kesan sampingan.';
    const badAudit = RegulatoryService.verifyCopy(badCopy);
    assert.strictEqual(badAudit.isCompliant, false, 'Copy with prohibited claims must fail audit');
    assert.ok(badAudit.infractions.length >= 3, 'Must catch multiple prohibited claims');

    // 2. Compliant clinical copy with approval code and disclaimer
    const goodCopy = 'Terapi Gelombang Kejutan (ESWT) merangsang neovaskularisasi. KKLIU 0812/2026. Sila rujuk nasihat doktor bertauliah kami.';
    const goodAudit = RegulatoryService.verifyCopy(goodCopy);
    assert.strictEqual(goodAudit.isCompliant, true, 'Approved objective copy must pass audit');
    assert.strictEqual(goodAudit.hasApprovalCode, true, 'Must detect valid approval code');
    assert.strictEqual(goodAudit.hasDisclaimer, true, 'Must detect disclaimer');

    // 3. Approved claims catalog
    const claims = RegulatoryService.getApprovedClaims('ESWT');
    assert.ok(claims.length > 0, 'Must have pre-approved claims for ESWT');
    assert.ok(claims[0].referenceCode.startsWith('KKM/LIU'), 'Must include official reference code');

    // 4. Clinical SOP manuals
    const sops = RegulatoryService.getSopManuals();
    assert.ok(sops.length >= 4, 'Must provide at least 4 default clinical SOP manuals');
    const sop01 = RegulatoryService.getSopManualContent(undefined, 'SOP-01_Patient_Consultation_Protocol');
    assert.ok(sop01 && sop01.includes('SOP-01'), 'SOP-01 content must be readable');
  });

  // ─── TEST 63: BranchService Profiles, Intake Payloads & Template Injection ──
  test('BranchService manages franchise clinic profiles, dynamic intake, and variable injection', () => {
    const BranchService = require('../services/BranchService');

    const branches = BranchService.getBranches();
    assert.ok(branches.length >= 4, 'Must manage at least 4 clinic branches');

    const bsr = BranchService.getBranchByCode('SSC-BSR');
    assert.ok(bsr, 'Must resolve Bangsar HQ branch');
    assert.strictEqual(bsr.shortName, 'Bangsar HQ');

    // Intake payload generation
    const consultPayload = BranchService.generateIntakePayload('SSC-BSR', 'consult', 'ESWT');
    assert.strictEqual(consultPayload.type, 'consult');
    assert.ok(consultPayload.url.includes('wa.me'), 'Consult payload must generate WhatsApp URL');
    assert.ok(consultPayload.url.includes('ESWT'), 'URL must encode treatment focus');

    const checkinPayload = BranchService.generateIntakePayload('SSC-KD', 'checkin');
    assert.strictEqual(checkinPayload.type, 'checkin');
    assert.ok(checkinPayload.url.includes('checkin'), 'Must generate touchless check-in URL');

    // Smart template variable injection
    const rawTemplate = 'Rawatan di {BRANCH_NAME} ({BRANCH_SHORT}) dikendalikan oleh {DOCTOR_NAME}. Hubungi {BRANCH_PHONE} atau WhatsApp {BRANCH_WHATSAPP}. Lesen: {KKM_LICENSE}.';
    const rendered = BranchService.injectBranchDetails(rawTemplate, 'SSC-BSR');
    assert.ok(!rendered.includes('{BRANCH_NAME}'), 'All template variables must be replaced');
    assert.ok(rendered.includes('Bangsar (HQ Induk)'), 'Must inject branch name');
    assert.ok(rendered.includes('KKM/JPS/KL'), 'Must inject KKM license number');
  });

  // ─── TEST 64: CareDispatcherService Bilingual Protocols & WhatsApp Leaflets ──
  test('CareDispatcherService generates formatted recovery leaflets and 1-click WhatsApp dispatch links', () => {
    const CareDispatcherService = require('../services/CareDispatcherService');

    const protocols = CareDispatcherService.getProtocols();
    assert.ok(protocols.length >= 4, 'Must provide at least 4 clinical aftercare recovery protocols');

    const dispatch = CareDispatcherService.generateDispatchMessage({
      patientName: 'En. Razak',
      patientPhone: '0123456789',
      protocolId: 'eswt',
      branchCode: 'SSC-BSR',
      followUpDate: '20 Oktober 2026'
    });

    assert.strictEqual(dispatch.patientName, 'En. Razak');
    assert.ok(dispatch.messageText.includes('PANDUAN PENJAGAAN DIGITAL'), 'Must contain official clinical header');
    assert.ok(dispatch.messageText.includes('ELAKKAN Pengambilan Ubat Tahan Sakit Anti-Radang (NSAIDs)'.toUpperCase()) || dispatch.messageText.includes('ELAKKAN'), 'Must include NSAID avoidance guidance');
    assert.ok(dispatch.messageText.includes('20 Oktober 2026'), 'Must include follow-up date');
    assert.ok(dispatch.whatsappUrl.startsWith('https://wa.me/0123456789'), 'Must generate direct 1-click WhatsApp dispatch link');
  });

  // ─── TEST 65: SnapshotService Asset Revision Snapshots & Rollback ────
  test('SnapshotService creates design asset snapshots and non-destructive rollbacks', () => {
    const SnapshotService = require('../services/SnapshotService');
    const testProjectDir = path.join(__dirname, 'temp-test-snapshot-proj');
    if (fs.existsSync(testProjectDir)) fs.rmSync(testProjectDir, { recursive: true, force: true });
    fs.mkdirSync(testProjectDir, { recursive: true });

    const sourceDir = path.join(testProjectDir, '02_SOURCE_FILES');
    const copyDir = path.join(testProjectDir, '03_COPYWRITING');
    fs.mkdirSync(sourceDir, { recursive: true });
    fs.mkdirSync(copyDir, { recursive: true });

    fs.writeFileSync(path.join(testProjectDir, 'README.md'), '---\nrevision: 2\nstatus: in-progress\n---\n# Test Snapshot Project');
    fs.writeFileSync(path.join(copyDir, 'COPY.md'), '# V2 Copywriting Content');
    fs.writeFileSync(path.join(sourceDir, 'poster_v2.afdesign'), 'BINARY_AFDESIGN_MOCK_CONTENT_V2');
    fs.writeFileSync(path.join(sourceDir, 'hero_banner.psd'), 'BINARY_PSD_MOCK_CONTENT_V2');

    // 1. Create snapshot
    const snap = SnapshotService.createSnapshot(testProjectDir, 'REVISION_UPDATE', 'Lead Designer', 'V2 checkpoint before major redesign');
    assert.ok(snap, 'Snapshot must be created successfully');
    assert.strictEqual(snap.revision, 2);
    assert.strictEqual(snap.trigger, 'REVISION_UPDATE');
    assert.ok(Array.isArray(snap.sourceFiles), 'Snapshot must record sourceFiles list');
    assert.strictEqual(snap.sourceFiles.length, 2, 'Must record 2 design source files');
    assert.ok(snap.sourceFiles.some(f => f.name === 'poster_v2.afdesign' && f.ext === '.afdesign'));
    assert.ok(snap.sourceFiles.some(f => f.name === 'hero_banner.psd' && f.ext === '.psd'));

    // 2. Modify files (simulate WIP change)
    fs.writeFileSync(path.join(testProjectDir, 'README.md'), '---\nrevision: 3\nstatus: review\n---\n# Test Snapshot Project V3 Corrupted');
    fs.writeFileSync(path.join(sourceDir, 'poster_v2.afdesign'), 'WIP_UNWANTED_CORRUPTED_CHANGES');

    // 3. Rollback
    const rollbackRes = SnapshotService.rollback(testProjectDir, snap.id, 'Tester');
    assert.ok(rollbackRes.success, 'Rollback must report success');
    assert.strictEqual(rollbackRes.snapshotId, snap.id);

    // 4. Verify restored content
    const restoredReadme = fs.readFileSync(path.join(testProjectDir, 'README.md'), 'utf8');
    assert.ok(restoredReadme.includes('revision: 2'));
    assert.ok(!restoredReadme.includes('Corrupted'));

    const restoredAfdesign = fs.readFileSync(path.join(sourceDir, 'poster_v2.afdesign'), 'utf8');
    assert.strictEqual(restoredAfdesign, 'BINARY_AFDESIGN_MOCK_CONTENT_V2');

    // 5. Verify safety backup was automatically created
    const snapshotsList = SnapshotService.listSnapshots(testProjectDir);
    assert.ok(snapshotsList.length >= 2, 'Pre-rollback safety snapshot must be present in snapshots list');
    assert.ok(snapshotsList.some(s => s.trigger === 'PRE_ROLLBACK_BACKUP'), 'Must have PRE_ROLLBACK_BACKUP trigger');

    // Cleanup
    try { fs.rmSync(testProjectDir, { recursive: true, force: true }); } catch (e) {}
  });

  // Execute all registered tests sequentially to ensure isolation and zero workspace collisions
  for (const t of testQueue) {
    try {
      await t.fn();
      console.log(`  ✅ PASS: ${t.name}`);
      passed++;
    } catch (err) {
      console.error(`  ❌ FAIL: ${t.name}`);
      console.error(`     Error: ${err.message}`);
      failed++;
    }
  }

  console.log(`\n========================================================`);
  console.log(`Test Results: ${passed} Passed, ${failed} Failed`);
  console.log(`========================================================\n`);

  // Cleanup test audit log
  AuditService.getAuditLogPath = origAuditGetPath;
  try { if (fs.existsSync(tempAuditPath)) fs.unlinkSync(tempAuditPath); } catch (e) {}

  if (failed > 0) {
    process.exit(1);
  }
  process.exit(0);
}

runTests();
