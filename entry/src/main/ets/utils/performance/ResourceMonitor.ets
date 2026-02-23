import { Logger } from './Logger';

const TAG = 'ResourceMonitor';

export enum ResourceLevel {
  CRITICAL = 'critical',
  LOW = 'low',
  NORMAL = 'normal',
  HIGH = 'high',
  ABUNDANT = 'abundant'
}

export interface ResourceMetrics {
  timestamp: number;
  cpu: CPUMetrics;
  memory: MemoryMetrics;
  network: NetworkMetrics;
  battery: BatteryMetrics;
  thermal: ThermalMetrics;
  overall: OverallResourceStatus;
}

export interface CPUMetrics {
  usage: number;
  loadAverage: number[];
  coreCount: number;
  temperature: number;
}

export interface MemoryMetrics {
  total: number;
  used: number;
  available: number;
  usagePercent: number;
  cacheSize: number;
  pressure: ResourceLevel;
}

export interface NetworkMetrics {
  type: 'wifi' | 'cellular' | 'ethernet' | 'unknown';
  isConnected: boolean;
  bandwidth: number;
  latency: number;
  signalStrength: number;
  isExpensive: boolean;
}

export interface BatteryMetrics {
  level: number;
  isCharging: boolean;
  isLow: boolean;
  temperature: number;
  health: string;
}

export interface ThermalMetrics {
  level: number;
  status: 'normal' | 'warm' | 'hot' | 'critical';
}

export interface OverallResourceStatus {
  level: ResourceLevel;
  score: number;
  recommendations: string[];
  canHandleTask: boolean;
  suggestedConcurrency: number;
}

export interface ResourceThresholds {
  cpuHigh: number;
  cpuCritical: number;
  memoryHigh: number;
  memoryCritical: number;
  batteryLow: number;
  thermalWarning: number;
  thermalCritical: number;
}

export interface MonitorConfig {
  sampleInterval: number;
  historySize: number;
  enableThermalMonitoring: boolean;
  enableBatteryMonitoring: boolean;
  enableNetworkMonitoring: boolean;
}

interface ResourceHistory {
  cpu: number[];
  memory: number[];
  network: number[];
  timestamps: number[];
}

export class ResourceMonitor {
  private static instance: ResourceMonitor | null = null;
  private currentMetrics: ResourceMetrics | null = null;
  private history: ResourceHistory = {
    cpu: [],
    memory: [],
    network: [],
    timestamps: []
  };
  private isMonitoring: boolean = false;
  private monitorTimer: number = 0;
  private config: MonitorConfig = {
    sampleInterval: 5000,
    historySize: 60,
    enableThermalMonitoring: true,
    enableBatteryMonitoring: true,
    enableNetworkMonitoring: true
  };
  private thresholds: ResourceThresholds = {
    cpuHigh: 70,
    cpuCritical: 90,
    memoryHigh: 75,
    memoryCritical: 90,
    batteryLow: 20,
    thermalWarning: 2,
    thermalCritical: 3
  };
  private onResourceChange?: (metrics: ResourceMetrics) => void;
  private onResourceWarning?: (level: ResourceLevel, message: string) => void;
  private activeTaskCount: number = 0;
  private maxAllowedTasks: number = 5;

  private constructor() {
    this.initializeMetrics();
  }

  static getInstance(): ResourceMonitor {
    if (!ResourceMonitor.instance) {
      ResourceMonitor.instance = new ResourceMonitor();
    }
    return ResourceMonitor.instance;
  }

  private initializeMetrics(): void {
    this.currentMetrics = {
      timestamp: Date.now(),
      cpu: {
        usage: 0,
        loadAverage: [0, 0, 0],
        coreCount: 4,
        temperature: 0
      },
      memory: {
        total: 0,
        used: 0,
        available: 0,
        usagePercent: 0,
        cacheSize: 0,
        pressure: ResourceLevel.NORMAL
      },
      network: {
        type: 'unknown',
        isConnected: true,
        bandwidth: 0,
        latency: 0,
        signalStrength: 0,
        isExpensive: false
      },
      battery: {
        level: 100,
        isCharging: true,
        isLow: false,
        temperature: 0,
        health: 'good'
      },
      thermal: {
        level: 0,
        status: 'normal'
      },
      overall: {
        level: ResourceLevel.NORMAL,
        score: 100,
        recommendations: [],
        canHandleTask: true,
        suggestedConcurrency: 3
      }
    };
  }

  startMonitoring(): void {
    if (this.isMonitoring) return;

    this.isMonitoring = true;
    this.collectMetrics();

    this.monitorTimer = setInterval(() => {
      this.collectMetrics();
    }, this.config.sampleInterval);

    Logger.info(TAG, '资源监控已启动');
  }

  stopMonitoring(): void {
    if (!this.isMonitoring) return;

    this.isMonitoring = false;
    if (this.monitorTimer) {
      clearInterval(this.monitorTimer);
      this.monitorTimer = 0;
    }

    Logger.info(TAG, '资源监控已停止');
  }

  private async collectMetrics(): Promise<void> {
    const startTime = Date.now();

    try {
      const cpuMetrics = await this.collectCPUMetrics();
      const memoryMetrics = this.collectMemoryMetrics();
      const networkMetrics = this.collectNetworkMetrics();
      const batteryMetrics = this.collectBatteryMetrics();
      const thermalMetrics = this.collectThermalMetrics();

      this.currentMetrics = {
        timestamp: Date.now(),
        cpu: cpuMetrics,
        memory: memoryMetrics,
        network: networkMetrics,
        battery: batteryMetrics,
        thermal: thermalMetrics,
        overall: this.calculateOverallStatus(cpuMetrics, memoryMetrics, networkMetrics, batteryMetrics, thermalMetrics)
      };

      this.updateHistory(cpuMetrics.usage, memoryMetrics.usagePercent, networkMetrics.bandwidth);

      this.checkThresholds();

      this.onResourceChange?.(this.currentMetrics);

      const elapsed = Date.now() - startTime;
      Logger.debug(TAG, `资源采集完成, 耗时: ${elapsed}ms`);
    } catch (error) {
      Logger.error(TAG, `资源采集失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async collectCPUMetrics(): Promise<CPUMetrics> {
    const simulatedUsage = this.simulateCPUUsage();

    return {
      usage: simulatedUsage,
      loadAverage: [simulatedUsage * 0.8, simulatedUsage * 0.6, simulatedUsage * 0.4],
      coreCount: 4,
      temperature: 35 + simulatedUsage * 0.3
    };
  }

  private simulateCPUUsage(): number {
    const baseUsage = 20 + this.activeTaskCount * 10;
    const variance = Math.random() * 20 - 10;
    return Math.min(100, Math.max(0, baseUsage + variance));
  }

  private collectMemoryMetrics(): MemoryMetrics {
    const totalMemory = 4 * 1024 * 1024 * 1024;
    const baseUsed = 1.5 * 1024 * 1024 * 1024;
    const taskMemory = this.activeTaskCount * 50 * 1024 * 1024;
    const variance = Math.random() * 200 * 1024 * 1024;

    const used = Math.min(totalMemory, baseUsed + taskMemory + variance);
    const available = totalMemory - used;
    const usagePercent = (used / totalMemory) * 100;

    let pressure = ResourceLevel.NORMAL;
    if (usagePercent > 90) {
      pressure = ResourceLevel.CRITICAL;
    } else if (usagePercent > 75) {
      pressure = ResourceLevel.LOW;
    } else if (usagePercent > 50) {
      pressure = ResourceLevel.NORMAL;
    } else {
      pressure = ResourceLevel.HIGH;
    }

    return {
      total: totalMemory,
      used,
      available,
      usagePercent,
      cacheSize: 100 * 1024 * 1024,
      pressure
    };
  }

  private collectNetworkMetrics(): NetworkMetrics {
    const bandwidth = this.isMonitoring ? 10 * 1024 * 1024 : 0;
    const latency = this.isMonitoring ? 50 + Math.random() * 50 : 0;

    return {
      type: 'wifi',
      isConnected: true,
      bandwidth,
      latency,
      signalStrength: 80 + Math.random() * 20,
      isExpensive: false
    };
  }

  private collectBatteryMetrics(): BatteryMetrics {
    const level = 100 - Math.random() * 30;
    const isCharging = Math.random() > 0.5;

    return {
      level,
      isCharging,
      isLow: level < this.thresholds.batteryLow,
      temperature: 30 + Math.random() * 10,
      health: 'good'
    };
  }

  private collectThermalMetrics(): ThermalMetrics {
    const baseLevel = this.currentMetrics?.thermal.level ?? 0;
    const taskHeat = this.activeTaskCount * 0.3;
    const level = Math.min(4, Math.max(0, baseLevel + (Math.random() - 0.5) + taskHeat));

    let status: 'normal' | 'warm' | 'hot' | 'critical' = 'normal';
    if (level >= 3) {
      status = 'critical';
    } else if (level >= 2) {
      status = 'hot';
    } else if (level >= 1) {
      status = 'warm';
    }

    return {
      level,
      status
    };
  }

  private calculateOverallStatus(
    cpu: CPUMetrics,
    memory: MemoryMetrics,
    network: NetworkMetrics,
    battery: BatteryMetrics,
    thermal: ThermalMetrics
  ): OverallResourceStatus {
    let score = 100;
    const recommendations: string[] = [];

    if (cpu.usage > this.thresholds.cpuCritical) {
      score -= 40;
      recommendations.push('CPU使用率过高，建议减少后台任务');
    } else if (cpu.usage > this.thresholds.cpuHigh) {
      score -= 20;
      recommendations.push('CPU使用率较高，注意监控');
    }

    if (memory.usagePercent > this.thresholds.memoryCritical) {
      score -= 35;
      recommendations.push('内存严重不足，建议清理缓存');
    } else if (memory.usagePercent > this.thresholds.memoryHigh) {
      score -= 15;
      recommendations.push('内存使用率较高');
    }

    if (!network.isConnected) {
      score -= 30;
      recommendations.push('网络未连接');
    } else if (network.latency > 200) {
      score -= 10;
      recommendations.push('网络延迟较高');
    }

    if (battery.isLow && !battery.isCharging) {
      score -= 15;
      recommendations.push('电量低，建议减少后台活动');
    }

    if (thermal.status === 'critical') {
      score -= 30;
      recommendations.push('设备过热，建议暂停后台任务');
    } else if (thermal.status === 'hot') {
      score -= 15;
      recommendations.push('设备温度较高');
    }

    score = Math.max(0, Math.min(100, score));

    let level: ResourceLevel;
    if (score >= 80) {
      level = ResourceLevel.ABUNDANT;
    } else if (score >= 60) {
      level = ResourceLevel.HIGH;
    } else if (score >= 40) {
      level = ResourceLevel.NORMAL;
    } else if (score >= 20) {
      level = ResourceLevel.LOW;
    } else {
      level = ResourceLevel.CRITICAL;
    }

    const suggestedConcurrency = this.calculateSuggestedConcurrency(level, score);
    const canHandleTask = level !== ResourceLevel.CRITICAL && suggestedConcurrency > 0;

    return {
      level,
      score,
      recommendations,
      canHandleTask,
      suggestedConcurrency
    };
  }

  private calculateSuggestedConcurrency(level: ResourceLevel, score: number): number {
    switch (level) {
      case ResourceLevel.ABUNDANT:
        return this.maxAllowedTasks;
      case ResourceLevel.HIGH:
        return Math.max(3, this.maxAllowedTasks - 1);
      case ResourceLevel.NORMAL:
        return Math.max(2, this.maxAllowedTasks - 2);
      case ResourceLevel.LOW:
        return 1;
      case ResourceLevel.CRITICAL:
        return 0;
      default:
        return 2;
    }
  }

  private updateHistory(cpu: number, memory: number, network: number): void {
    this.history.cpu.push(cpu);
    this.history.memory.push(memory);
    this.history.network.push(network);
    this.history.timestamps.push(Date.now());

    if (this.history.cpu.length > this.config.historySize) {
      this.history.cpu.shift();
      this.history.memory.shift();
      this.history.network.shift();
      this.history.timestamps.shift();
    }
  }

  private checkThresholds(): void {
    if (!this.currentMetrics) return;

    const metrics = this.currentMetrics;

    if (metrics.cpu.usage > this.thresholds.cpuCritical) {
      this.onResourceWarning?.(ResourceLevel.CRITICAL, `CPU使用率过高: ${metrics.cpu.usage.toFixed(1)}%`);
    }

    if (metrics.memory.usagePercent > this.thresholds.memoryCritical) {
      this.onResourceWarning?.(ResourceLevel.CRITICAL, `内存不足: ${metrics.memory.usagePercent.toFixed(1)}%`);
    }

    if (metrics.thermal.status === 'critical') {
      this.onResourceWarning?.(ResourceLevel.CRITICAL, '设备温度过高');
    }

    if (metrics.battery.isLow && !metrics.battery.isCharging) {
      this.onResourceWarning?.(ResourceLevel.LOW, `电量低: ${metrics.battery.level.toFixed(0)}%`);
    }
  }

  getCurrentMetrics(): ResourceMetrics | null {
    return this.currentMetrics;
  }

  getResourceLevel(): ResourceLevel {
    return this.currentMetrics?.overall.level ?? ResourceLevel.NORMAL;
  }

  canHandleNewTask(): boolean {
    if (!this.currentMetrics) return true;
    return this.currentMetrics.overall.canHandleTask && this.activeTaskCount < this.maxAllowedTasks;
  }

  getSuggestedConcurrency(): number {
    return this.currentMetrics?.overall.suggestedConcurrency ?? 3;
  }

  registerTaskStart(): void {
    this.activeTaskCount++;
    Logger.debug(TAG, `任务开始, 当前活跃任务数: ${this.activeTaskCount}`);
  }

  registerTaskEnd(): void {
    this.activeTaskCount = Math.max(0, this.activeTaskCount - 1);
    Logger.debug(TAG, `任务结束, 当前活跃任务数: ${this.activeTaskCount}`);
  }

  getActiveTaskCount(): number {
    return this.activeTaskCount;
  }

  getHistory(): ResourceHistory {
    return {
      cpu: this.history.cpu,
      memory: this.history.memory,
      network: this.history.network,
      timestamps: this.history.timestamps
    };
  }

  getAverageCPU(): number {
    if (this.history.cpu.length === 0) return 0;
    return this.history.cpu.reduce((a, b) => a + b, 0) / this.history.cpu.length;
  }

  getAverageMemory(): number {
    if (this.history.memory.length === 0) return 0;
    return this.history.memory.reduce((a, b) => a + b, 0) / this.history.memory.length;
  }

  getTrend(): 'improving' | 'stable' | 'declining' {
    if (this.history.cpu.length < 5) return 'stable';

    const recentCpu = this.history.cpu.slice(-5);
    const olderCpu = this.history.cpu.slice(-10, -5);

    if (olderCpu.length === 0) return 'stable';

    const recentAvg = recentCpu.reduce((a, b) => a + b, 0) / recentCpu.length;
    const olderAvg = olderCpu.reduce((a, b) => a + b, 0) / olderCpu.length;

    const diff = olderAvg - recentAvg;

    if (diff > 10) return 'improving';
    if (diff < -10) return 'declining';
    return 'stable';
  }

  setOnResourceChange(callback: (metrics: ResourceMetrics) => void): void {
    this.onResourceChange = callback;
  }

  setOnResourceWarning(callback: (level: ResourceLevel, message: string) => void): void {
    this.onResourceWarning = callback;
  }

  setConfig(config: Partial<MonitorConfig>): void {
    if (config.sampleInterval !== undefined) {
      this.config.sampleInterval = config.sampleInterval;
    }
    if (config.historySize !== undefined) {
      this.config.historySize = config.historySize;
    }
    if (config.enableThermalMonitoring !== undefined) {
      this.config.enableThermalMonitoring = config.enableThermalMonitoring;
    }
    if (config.enableBatteryMonitoring !== undefined) {
      this.config.enableBatteryMonitoring = config.enableBatteryMonitoring;
    }
    if (config.enableNetworkMonitoring !== undefined) {
      this.config.enableNetworkMonitoring = config.enableNetworkMonitoring;
    }
  }

  setThresholds(thresholds: Partial<ResourceThresholds>): void {
    if (thresholds.cpuHigh !== undefined) {
      this.thresholds.cpuHigh = thresholds.cpuHigh;
    }
    if (thresholds.cpuCritical !== undefined) {
      this.thresholds.cpuCritical = thresholds.cpuCritical;
    }
    if (thresholds.memoryHigh !== undefined) {
      this.thresholds.memoryHigh = thresholds.memoryHigh;
    }
    if (thresholds.memoryCritical !== undefined) {
      this.thresholds.memoryCritical = thresholds.memoryCritical;
    }
    if (thresholds.batteryLow !== undefined) {
      this.thresholds.batteryLow = thresholds.batteryLow;
    }
    if (thresholds.thermalWarning !== undefined) {
      this.thresholds.thermalWarning = thresholds.thermalWarning;
    }
    if (thresholds.thermalCritical !== undefined) {
      this.thresholds.thermalCritical = thresholds.thermalCritical;
    }
  }

  setMaxAllowedTasks(max: number): void {
    this.maxAllowedTasks = Math.max(1, Math.min(10, max));
  }

  destroy(): void {
    this.stopMonitoring();
    this.currentMetrics = null;
    this.history = {
      cpu: [],
      memory: [],
      network: [],
      timestamps: []
    };
    Logger.info(TAG, '资源监控器已销毁');
  }
}

export default ResourceMonitor.getInstance();
