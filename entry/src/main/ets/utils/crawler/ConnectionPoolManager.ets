import { IConnectionPoolManager, ConnectionHandle, ConnectionPoolMetrics, DomainConnectionStats } from "./interfaces/IConcurrency";
import { Logger } from "../performance/Logger";

interface PooledConnection extends ConnectionHandle {
  responseTime: number;
}

interface DomainPool {
  connections: PooledConnection[];
  maxPerDomain: number;
}

export class ConnectionPoolManager implements IConnectionPoolManager {
  private static readonly TAG = 'ConnectionPoolManager';
  private static readonly MAX_IDLE_MS = 30000;
  private static readonly MAX_MEMORY_BYTES = 256 * 1024 * 1024;
  private static readonly CLEANUP_INTERVAL_MS = 10000;

  private pools: Map<string, DomainPool> = new Map();
  private maxPerDomain: number;
  private totalCreated: number = 0;
  private totalAcquired: number = 0;
  private cleanupTimer: number | null = null;

  constructor(maxPerDomain: number = 10) {
    this.maxPerDomain = maxPerDomain;
    this.startCleanup();
  }

  async acquire(domain: string): Promise<ConnectionHandle> {
    const pool = this.getOrCreatePool(domain);

    const idleConn = pool.connections.find((c: PooledConnection) =>
      !c.isActive && (Date.now() - c.lastUsedAt) < ConnectionPoolManager.MAX_IDLE_MS
    );

    if (idleConn) {
      idleConn.isActive = true;
      idleConn.lastUsedAt = Date.now();
      this.totalAcquired++;
      Logger.debug(ConnectionPoolManager.TAG, `Reusing idle connection ${idleConn.id} for ${domain}`);
      return idleConn;
    }

    if (pool.connections.length < pool.maxPerDomain) {
      const conn = this.createConnection(domain);
      pool.connections.push(conn);
      this.totalAcquired++;
      Logger.debug(ConnectionPoolManager.TAG, `Created new connection ${conn.id} for ${domain}`);
      return conn;
    }

    Logger.debug(ConnectionPoolManager.TAG, `Waiting for connection to ${domain}, pool full`);
    return new Promise<ConnectionHandle>((resolve: Function) => {
      const checkInterval = setInterval(() => {
        const idleConn = pool.connections.find((c: PooledConnection) => !c.isActive);
        if (idleConn) {
          idleConn.isActive = true;
          idleConn.lastUsedAt = Date.now();
          this.totalAcquired++;
          clearInterval(checkInterval);
          resolve(idleConn);
        }
      }, 100);

      setTimeout(() => {
        clearInterval(checkInterval);
        const conn = this.createConnection(domain);
        pool.connections.push(conn);
        this.totalAcquired++;
        resolve(conn);
      }, 5000);
    });
  }

  release(handle: ConnectionHandle): void {
    const pool = this.pools.get(handle.domain);
    if (!pool) return;

    const conn = pool.connections.find((c: PooledConnection) => c.id === handle.id);
    if (conn) {
      conn.isActive = false;
      conn.lastUsedAt = Date.now();
      Logger.debug(ConnectionPoolManager.TAG, `Released connection ${handle.id}`);
    }
  }

  getMetrics(): ConnectionPoolMetrics {
    let totalActive = 0;
    let totalIdle = 0;
    const domainStats = new Map<string, DomainConnectionStats>();

    this.pools.forEach((pool: DomainPool, domain: string) => {
      const active = pool.connections.filter((c: PooledConnection) => c.isActive).length;
      const idle = pool.connections.length - active;
      totalActive += active;
      totalIdle += idle;

      domainStats.set(domain, {
        domain: domain,
        total: pool.connections.length,
        active: active,
        idle: idle,
      });
    });

    return {
      totalConnections: totalActive + totalIdle,
      activeConnections: totalActive,
      idleConnections: totalIdle,
      domainStats: domainStats,
      memoryUsageBytes: this.estimateMemoryUsage(),
    };
  }

  cleanup(): number {
    let cleaned = 0;
    const now = Date.now();

    this.pools.forEach((pool: DomainPool, domain: string) => {
      const before = pool.connections.length;
      pool.connections = pool.connections.filter((c: PooledConnection) => {
        if (!c.isActive && (now - c.lastUsedAt) > ConnectionPoolManager.MAX_IDLE_MS) {
          Logger.debug(ConnectionPoolManager.TAG, `Cleaning idle connection ${c.id}`);
          return false;
        }
        return true;
      });
      cleaned += before - pool.connections.length;
    });

    return cleaned;
  }

  shutdown(): void {
    if (this.cleanupTimer !== null) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }

    this.pools.forEach((pool: DomainPool) => {
      pool.connections.forEach((c: PooledConnection) => {
        c.isActive = false;
      });
      pool.connections = [];
    });
    this.pools.clear();
    Logger.info(ConnectionPoolManager.TAG, 'Connection pool shutdown complete');
  }

  private getOrCreatePool(domain: string): DomainPool {
    let pool = this.pools.get(domain);
    if (!pool) {
      pool = { connections: [], maxPerDomain: this.maxPerDomain };
      this.pools.set(domain, pool);
    }
    return pool;
  }

  private createConnection(domain: string): PooledConnection {
    const now = Date.now();
    this.totalCreated++;
    return {
      id: `conn_${domain}_${this.totalCreated}`,
      domain: domain,
      createdAt: now,
      lastUsedAt: now,
      isActive: true,
      responseTime: 0,
    };
  }

  private startCleanup(): void {
    this.cleanupTimer = setInterval(() => {
      const cleaned = this.cleanup();
      if (cleaned > 0) {
        Logger.debug(ConnectionPoolManager.TAG, `Periodic cleanup: removed ${cleaned} idle connections`);
      }
    }, ConnectionPoolManager.CLEANUP_INTERVAL_MS);
  }

  private estimateMemoryUsage(): number {
    let total = 0;
    this.pools.forEach((pool: DomainPool) => {
      total += pool.connections.length * 4096;
    });
    return total;
  }
}
