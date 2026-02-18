/**
 * 文档更新机制
 * 自动化文档版本管理和变更追踪
 */

export interface DocVersion {
  version: string;
  releaseDate: number;
  changes: DocChange[];
}

export interface DocChange {
  type: 'added' | 'changed' | 'deprecated' | 'removed' | 'fixed';
  module: string;
  description: string;
  breaking: boolean;
  migration?: string;
}

export interface DocUpdateConfig {
  versionFile: string;
  changelogFile: string;
  apiDocFile: string;
}

export interface PartialDocChange {
  type: 'added' | 'changed' | 'deprecated' | 'removed' | 'fixed';
  module: string;
  description: string;
  breaking?: boolean;
  migration?: string;
}

export class DocVersionManager {
  private static instance: DocVersionManager | null = null;


  private pendingChanges: DocChange[] = new Array<DocChange>();

  private constructor() {}

  static getInstance(): DocVersionManager {
    if (!DocVersionManager.instance) {
      DocVersionManager.instance = new DocVersionManager();
    }
    return DocVersionManager.instance;
  }

  addChange(change: PartialDocChange): void {
    const newChange: DocChange = {
      type: change.type,
      module: change.module,
      description: change.description,
      breaking: change.breaking !== undefined ? change.breaking : false,
      migration: change.migration
    } as DocChange;
    this.pendingChanges.push(newChange);
  }

  recordApiAdded(module: string, description: string): void {
    const change: PartialDocChange = {
      type: 'added',
      module: module,
      description: description,
      breaking: false
    } as PartialDocChange;
    this.addChange(change);
  }

  recordApiChanged(module: string, description: string, breaking: boolean = false, migration?: string): void {
    const change: PartialDocChange = {
      type: 'changed',
      module: module,
      description: description,
      breaking: breaking,
      migration: migration
    } as PartialDocChange;
    this.addChange(change);
  }

  recordApiDeprecated(module: string, description: string, migration?: string): void {
    const change: PartialDocChange = {
      type: 'deprecated',
      module: module,
      description: description,
      breaking: false,
      migration: migration
    } as PartialDocChange;
    this.addChange(change);
  }

  recordApiRemoved(module: string, description: string, migration?: string): void {
    const change: PartialDocChange = {
      type: 'removed',
      module: module,
      description: description,
      breaking: true,
      migration: migration
    } as PartialDocChange;
    this.addChange(change);
  }

  recordBugFixed(module: string, description: string): void {
    const change: PartialDocChange = {
      type: 'fixed',
      module: module,
      description: description,
      breaking: false
    } as PartialDocChange;
    this.addChange(change);
  }

  hasPendingChanges(): boolean {
    return this.pendingChanges.length > 0;
  }

  getPendingChanges(): DocChange[] {
    const changes: DocChange[] = new Array<DocChange>();
    for (let i = 0; i < this.pendingChanges.length; i++) {
      changes.push(this.pendingChanges[i]);
    }
    return changes;
  }

  hasBreakingChanges(): boolean {
    for (let i = 0; i < this.pendingChanges.length; i++) {
      if (this.pendingChanges[i].breaking) {
        return true;
      }
    }
    return false;
  }

  suggestVersionBump(): 'major' | 'minor' | 'patch' {
    if (this.hasBreakingChanges()) {
      return 'major';
    }

    let hasNewFeatures = false;
    for (let i = 0; i < this.pendingChanges.length; i++) {
      if (this.pendingChanges[i].type === 'added') {
        hasNewFeatures = true;
        break;
      }
    }
    
    if (hasNewFeatures) {
      return 'minor';
    }

    return 'patch';
  }

  calculateNextVersion(currentVersion: string, bump: 'major' | 'minor' | 'patch'): string {
    const parts = currentVersion.split('.').map(Number);
    const major = parts[0];
    const minor = parts[1];
    const patch = parts[2];

    if (bump === 'major') {
      return `${major + 1}.0.0`;
    } else if (bump === 'minor') {
      return `${major}.${minor + 1}.0`;
    } else {
      return `${major}.${minor}.${patch + 1}`;
    }
  }

  createVersion(version: string): DocVersion {
    const changes: DocChange[] = new Array<DocChange>();
    for (let i = 0; i < this.pendingChanges.length; i++) {
      changes.push(this.pendingChanges[i]);
    }

    const docVersion: DocVersion = {
      version: version,
      releaseDate: Date.now(),
      changes: changes
    } as DocVersion;

  
    this.pendingChanges = new Array<DocChange>();

    return docVersion;
  }

  generateChangelogEntry(version: DocVersion): string {
    const lines: string[] = new Array<string>();
    const date = new Date(version.releaseDate).toISOString().split('T')[0];

    lines.push(`## [${version.version}] - ${date}`);
    lines.push('');

    const groupedChanges = this.groupChangesByType(version.changes);

    const typeEntries = Object.entries(groupedChanges);
    for (let j = 0; j < typeEntries.length; j++) {
      const type = typeEntries[j][0];
      const changes = typeEntries[j][1];
      if (changes.length === 0) continue;

      const typeName = this.getTypeName(type);
      lines.push(`### ${typeName}`);
      lines.push('');

      for (let k = 0; k < changes.length; k++) {
        const change = changes[k];
        let line = `- ${change.description} (\`${change.module}\`)`;
        if (change.breaking) {
          line += ' **BREAKING**';
        }
        lines.push(line);

        if (change.migration) {
          lines.push(`  - 迁移指南: ${change.migration}`);
        }
      }
      lines.push('');
    }

    return lines.join('\n');
  }

  private groupChangesByType(changes: DocChange[]): Record<string, DocChange[]> {
    const groups: Record<string, DocChange[]> = {};
    groups['added'] = new Array<DocChange>();
    groups['changed'] = new Array<DocChange>();
    groups['deprecated'] = new Array<DocChange>();
    groups['removed'] = new Array<DocChange>();
    groups['fixed'] = new Array<DocChange>();

    for (let i = 0; i < changes.length; i++) {
      const change = changes[i];
      if (groups[change.type]) {
        groups[change.type].push(change);
      }
    }

    return groups;
  }

  private getTypeName(type: string): string {
    const names: Record<string, string> = {};
    names['added'] = '新增';
    names['changed'] = '变更';
    names['deprecated'] = '废弃';
    names['removed'] = '移除';
    names['fixed'] = '修复';
    return names[type] || type;
  }

  generateApiDiff(oldVersion: DocVersion, newVersion: DocVersion): string {
    const lines: string[] = new Array<string>();

    lines.push(`# API 变更对比`);
    lines.push('');
    lines.push(`从版本 ${oldVersion.version} 到 ${newVersion.version}`);
    lines.push('');

    const oldApis = this.extractApis(oldVersion);
    const newApis = this.extractApis(newVersion);

    const added: string[] = new Array<string>();
    for (let i = 0; i < newApis.length; i++) {
      const api = newApis[i];
      let found = false;
      for (let j = 0; j < oldApis.length; j++) {
        if (oldApis[j] === api) {
          found = true;
          break;
        }
      }
      if (!found) {
        added.push(api);
      }
    }

    const removed: string[] = new Array<string>();
    for (let i = 0; i < oldApis.length; i++) {
      const api = oldApis[i];
      let found = false;
      for (let j = 0; j < newApis.length; j++) {
        if (newApis[j] === api) {
          found = true;
          break;
        }
      }
      if (!found) {
        removed.push(api);
      }
    }

    if (added.length > 0) {
      lines.push('## 新增 API');
      lines.push('');
      for (let i = 0; i < added.length; i++) {
        lines.push(`- \`${added[i]}\``);
      }
      lines.push('');
    }

    if (removed.length > 0) {
      lines.push('## 移除 API');
      lines.push('');
      for (let i = 0; i < removed.length; i++) {
        lines.push(`- \`${removed[i]}\``);
      }
      lines.push('');
    }

    return lines.join('\n');
  }

  private extractApis(version: DocVersion): string[] {
    const apis: string[] = new Array<string>();

    for (let i = 0; i < version.changes.length; i++) {
      const change = version.changes[i];
      if (change.type === 'added' || change.type === 'changed') {
        apis.push(change.module);
      }
    }

    const uniqueApis: string[] = new Array<string>();
    for (let i = 0; i < apis.length; i++) {
      const api = apis[i];
      let found = false;
      for (let j = 0; j < uniqueApis.length; j++) {
        if (uniqueApis[j] === api) {
          found = true;
          break;
        }
      }
      if (!found) {
        uniqueApis.push(api);
      }
    }

    return uniqueApis;
  }

  validateDocConsistency(apiDoc: string, codeExports: string[]): string[] {
    const issues: string[] = new Array<string>();
    const docApis = this.extractApisFromDoc(apiDoc);

    const missingInDoc: string[] = new Array<string>();
    for (let i = 0; i < codeExports.length; i++) {
      const api = codeExports[i];
      let found = false;
      for (let j = 0; j < docApis.length; j++) {
        if (docApis[j] === api) {
          found = true;
          break;
        }
      }
      if (!found) {
        missingInDoc.push(api);
      }
    }

    const missingInCode: string[] = new Array<string>();
    for (let i = 0; i < docApis.length; i++) {
      const api = docApis[i];
      let found = false;
      for (let j = 0; j < codeExports.length; j++) {
        if (codeExports[j] === api) {
          found = true;
          break;
        }
      }
      if (!found) {
        missingInCode.push(api);
      }
    }

    if (missingInDoc.length > 0) {
      issues.push(`文档缺失以下 API: ${missingInDoc.join(', ')}`);
    }

    if (missingInCode.length > 0) {
      issues.push(`代码缺失以下 API: ${missingInCode.join(', ')}`);
    }

    return issues;
  }

  private extractApisFromDoc(doc: string): string[] {
    const apis: string[] = new Array<string>();
    const regex = /`([a-zA-Z][a-zA-Z0-9]*)\s*\(/g;
    let match: RegExpExecArray | null;

    while ((match = regex.exec(doc)) !== null) {
      apis.push(match[1]);
    }

    const uniqueApis: string[] = new Array<string>();
    for (let i = 0; i < apis.length; i++) {
      const api = apis[i];
      let found = false;
      for (let j = 0; j < uniqueApis.length; j++) {
        if (uniqueApis[j] === api) {
          found = true;
          break;
        }
      }
      if (!found) {
        uniqueApis.push(api);
      }
    }

    return uniqueApis;
  }
}

export class DocUpdateChecker {
  private versionManager: DocVersionManager;

  constructor() {
    this.versionManager = DocVersionManager.getInstance();
  }

  checkForUpdates(): DocChange[] {
    const changes: DocChange[] = new Array<DocChange>();

    // 比较版本之间的变更
    // 实际实现中需要从版本历史中获取

    return changes;
  }

  getUpdateRecommendations(): string[] {
    const recommendations: string[] = new Array<string>();
    const pendingChanges = this.versionManager.getPendingChanges();

    if (pendingChanges.length === 0) {
      recommendations.push('没有待发布的变更');
      return recommendations;
    }

    if (this.versionManager.hasBreakingChanges()) {
      recommendations.push('检测到破坏性变更，建议发布主版本更新');
      recommendations.push('请确保更新迁移指南');
    }

    const deprecatedChanges: DocChange[] = new Array<DocChange>();
    for (let i = 0; i < pendingChanges.length; i++) {
      if (pendingChanges[i].type === 'deprecated') {
        deprecatedChanges.push(pendingChanges[i]);
      }
    }
    
    if (deprecatedChanges.length > 0) {
      recommendations.push(`有 ${deprecatedChanges.length} 个 API 被标记为废弃`);
      recommendations.push('建议在下一个主版本中移除这些 API');
    }

    return recommendations;
  }
}

export class DocSyncManager {
  private docFiles: Map<string, DocFileInfo> = new Map();

  registerDocFile(path: string, info: DocFileInfo): void {
    this.docFiles.set(path, info);
  }

  checkSyncStatus(): Map<string, SyncStatus> {
    const status = new Map<string, SyncStatus>();

    const entries = Array.from(this.docFiles.entries());
    for (let i = 0; i < entries.length; i++) {
      const path = entries[i][0];
      const syncStatus = new SyncStatusImpl(true, Date.now(), new Array<string>());
      status.set(path, syncStatus);
    }

    return status;
  }

  generateSyncReport(): string {
    const lines: string[] = new Array<string>();

    lines.push('# 文档同步报告');
    lines.push('');
    lines.push(`生成时间: ${new Date().toISOString()}`);
    lines.push('');

    const status = this.checkSyncStatus();
    const entries = Array.from(status.entries());

    for (let i = 0; i < entries.length; i++) {
      const path = entries[i][0];
      const syncStatus = entries[i][1];
      lines.push(`## ${path}`);
      lines.push('');

      if (syncStatus.synced) {
        lines.push('状态: ✅ 已同步');
      } else {
        lines.push('状态: ❌ 需要更新');
        for (let j = 0; j < syncStatus.issues.length; j++) {
          lines.push(`- ${syncStatus.issues[j]}`);
        }
      }
      lines.push('');
    }

    return lines.join('\n');
  }
}

export interface DocFileInfo {
  moduleName: string;
  lastUpdated: number;
  codeHash: string;
  docHash: string;
}

export interface SyncStatus {
  synced: boolean;
  lastSync: number;
  issues: string[];
}

export class SyncStatusImpl implements SyncStatus {
  synced: boolean;
  lastSync: number;
  issues: string[];

  constructor(synced: boolean, lastSync: number, issues: string[]) {
    this.synced = synced;
    this.lastSync = lastSync;
    this.issues = issues;
  }
}

export interface DocUpdateManagerExports {
  DocVersionManager: DocVersionManager;
  DocUpdateChecker: DocUpdateChecker;
  DocSyncManager: DocSyncManager;
}

const docUpdateManagerExports: DocUpdateManagerExports = {
  DocVersionManager: DocVersionManager.getInstance(),
  DocUpdateChecker: new DocUpdateChecker(),
  DocSyncManager: new DocSyncManager()
};

export default docUpdateManagerExports;