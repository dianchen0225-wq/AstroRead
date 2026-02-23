import { Logger } from '../performance/Logger';

const TAG = 'ReadingBehaviorMonitor';

export enum ReadingState {
  IDLE = 'idle',
  READING = 'reading',
  SCROLLING = 'scrolling',
  PAUSED = 'paused',
  CHAPTER_CHANGE = 'chapter_change',
  APP_BACKGROUND = 'app_background'
}

export interface ReadingSession {
  bookId: string;
  chapterId: string;
  startTime: number;
  lastActivityTime: number;
  scrollEvents: ScrollEvent[];
  pauseEvents: PauseEvent[];
  totalReadingTime: number;
  effectiveReadingTime: number;
  scrollDistance: number;
  averageScrollSpeed: number;
}

export interface ScrollEvent {
  timestamp: number;
  direction: 'up' | 'down';
  distance: number;
  speed: number;
}

export interface PauseEvent {
  timestamp: number;
  duration: number;
  reason: 'user' | 'system' | 'chapter_end';
}

export interface ReadingBehaviorStats {
  currentBookId: string | null;
  currentChapterId: string | null;
  readingState: ReadingState;
  sessionDuration: number;
  effectiveReadingTime: number;
  scrollCount: number;
  averageScrollSpeed: number;
  pauseCount: number;
  totalPauseTime: number;
  chapterChangeCount: number;
  readingSpeed: number;
  estimatedRemainingTime: number;
  engagementScore: number;
}

export interface BehaviorPrediction {
  likelyToContinue: boolean;
  confidence: number;
  predictedNextChapter: string | null;
  estimatedReadDuration: number;
  recommendedPreloadCount: number;
}

export interface MonitorConfig {
  scrollEventThreshold: number;
  pauseDetectionDelay: number;
  sessionTimeout: number;
  engagementThreshold: number;
  maxScrollEventsHistory: number;
  behaviorAnalysisInterval: number;
}

interface ChapterReadingRecord {
  chapterId: string;
  startTime: number;
  endTime?: number;
  scrollEvents: number;
  pauseTime: number;
  readingSpeed: number;
  completed: boolean;
}

export class ReadingBehaviorMonitor {
  private static instance: ReadingBehaviorMonitor | null = null;
  private currentSession: ReadingSession | null = null;
  private readingState: ReadingState = ReadingState.IDLE;
  private chapterRecords: Map<string, ChapterReadingRecord> = new Map();
  private lastScrollTime: number = 0;
  private lastPauseStartTime: number = 0;
  private scrollVelocityBuffer: number[] = [];
  private readingSpeedBuffer: number[] = [];
  private pauseTimer: number = 0;
  private analysisTimer: number = 0;
  private config: MonitorConfig = {
    scrollEventThreshold: 50,
    pauseDetectionDelay: 3000,
    sessionTimeout: 300000,
    engagementThreshold: 0.6,
    maxScrollEventsHistory: 100,
    behaviorAnalysisInterval: 10000
  };
  private onStateChange?: (state: ReadingState, session: ReadingSession | null) => void;
  private onBehaviorUpdate?: (stats: ReadingBehaviorStats) => void;
  private onPredictionUpdate?: (prediction: BehaviorPrediction) => void;

  private constructor() {
    this.startBehaviorAnalysis();
  }

  static getInstance(): ReadingBehaviorMonitor {
    if (!ReadingBehaviorMonitor.instance) {
      ReadingBehaviorMonitor.instance = new ReadingBehaviorMonitor();
    }
    return ReadingBehaviorMonitor.instance;
  }

  startReadingSession(bookId: string, chapterId: string): void {
    if (this.currentSession) {
      this.endReadingSession();
    }

    this.currentSession = {
      bookId,
      chapterId,
      startTime: Date.now(),
      lastActivityTime: Date.now(),
      scrollEvents: [],
      pauseEvents: [],
      totalReadingTime: 0,
      effectiveReadingTime: 0,
      scrollDistance: 0,
      averageScrollSpeed: 0
    };

    this.readingState = ReadingState.READING;
    this.chapterRecords.set(chapterId, {
      chapterId,
      startTime: Date.now(),
      scrollEvents: 0,
      pauseTime: 0,
      readingSpeed: 0,
      completed: false
    });

    Logger.info(TAG, `开始阅读会话: 书籍=${bookId}, 章节=${chapterId}`);
    this.notifyStateChange();
  }

  endReadingSession(): void {
    if (!this.currentSession) return;

    const session = this.currentSession;
    const record = this.chapterRecords.get(session.chapterId);

    if (record) {
      record.endTime = Date.now();
      record.readingSpeed = this.calculateReadingSpeed(session);
    }

    Logger.info(TAG, `结束阅读会话: 总时长=${session.totalReadingTime}ms, 有效阅读=${session.effectiveReadingTime}ms`);

    this.currentSession = null;
    this.readingState = ReadingState.IDLE;
    this.clearTimers();

    this.notifyStateChange();
  }

  recordScroll(direction: 'up' | 'down', distance: number, speed: number): void {
    if (!this.currentSession) return;

    const now = Date.now();
    this.lastScrollTime = now;
    this.currentSession.lastActivityTime = now;

    if (distance < this.config.scrollEventThreshold) return;

    const scrollEvent: ScrollEvent = {
      timestamp: now,
      direction,
      distance,
      speed
    };

    this.currentSession.scrollEvents.push(scrollEvent);
    this.currentSession.scrollDistance += distance;
    this.scrollVelocityBuffer.push(speed);

    if (this.currentSession.scrollEvents.length > this.config.maxScrollEventsHistory) {
      this.currentSession.scrollEvents.shift();
    }

    if (this.scrollVelocityBuffer.length > 20) {
      this.scrollVelocityBuffer.shift();
    }

    const record = this.chapterRecords.get(this.currentSession.chapterId);
    if (record) {
      record.scrollEvents++;
    }

    this.updateReadingState(ReadingState.SCROLLING);

    this.resetPauseTimer();

    if (this.readingState !== ReadingState.READING) {
      this.updateReadingState(ReadingState.READING);
    }
  }

  recordPause(reason: 'user' | 'system' | 'chapter_end' = 'user'): void {
    if (!this.currentSession) return;

    const now = Date.now();
    this.lastPauseStartTime = now;

    this.updateReadingState(ReadingState.PAUSED);

    Logger.debug(TAG, `记录暂停事件: 原因=${reason}`);
  }

  recordResume(): void {
    if (!this.currentSession) return;

    const now = Date.now();
    const pauseDuration = now - this.lastPauseStartTime;

    if (pauseDuration > this.config.pauseDetectionDelay) {
      this.currentSession.pauseEvents.push({
        timestamp: this.lastPauseStartTime,
        duration: pauseDuration,
        reason: 'user'
      });

      const record = this.chapterRecords.get(this.currentSession.chapterId);
      if (record) {
        record.pauseTime += pauseDuration;
      }
    }

    this.updateReadingState(ReadingState.READING);
    this.currentSession.lastActivityTime = now;
  }

  recordChapterChange(newChapterId: string): void {
    if (!this.currentSession) return;

    const oldChapterId = this.currentSession.chapterId;
    const record = this.chapterRecords.get(oldChapterId);

    if (record) {
      record.endTime = Date.now();
      record.completed = true;
      record.readingSpeed = this.calculateReadingSpeed(this.currentSession);
    }

    this.currentSession.chapterId = newChapterId;
    this.currentSession.lastActivityTime = Date.now();
    this.currentSession.scrollEvents = [];
    this.currentSession.scrollDistance = 0;

    this.chapterRecords.set(newChapterId, {
      chapterId: newChapterId,
      startTime: Date.now(),
      scrollEvents: 0,
      pauseTime: 0,
      readingSpeed: 0,
      completed: false
    });

    this.updateReadingState(ReadingState.CHAPTER_CHANGE);

    Logger.info(TAG, `章节切换: ${oldChapterId} -> ${newChapterId}`);

    setTimeout(() => {
      if (this.currentSession && this.currentSession.chapterId === newChapterId) {
        this.updateReadingState(ReadingState.READING);
      }
    }, 1000);
  }

  recordAppBackground(): void {
    this.updateReadingState(ReadingState.APP_BACKGROUND);
    this.recordPause('system');
    Logger.info(TAG, '应用进入后台');
  }

  recordAppForeground(): void {
    if (this.readingState === ReadingState.APP_BACKGROUND) {
      this.recordResume();
      Logger.info(TAG, '应用回到前台');
    }
  }

  private updateReadingState(newState: ReadingState): void {
    if (this.readingState !== newState) {
      const oldState = this.readingState;
      this.readingState = newState;
      Logger.debug(TAG, `阅读状态变更: ${oldState} -> ${newState}`);
      this.notifyStateChange();
    }
  }

  private resetPauseTimer(): void {
    if (this.pauseTimer) {
      clearTimeout(this.pauseTimer);
    }

    this.pauseTimer = setTimeout(() => {
      if (this.currentSession && Date.now() - this.lastScrollTime >= this.config.pauseDetectionDelay) {
        this.recordPause('user');
      }
    }, this.config.pauseDetectionDelay);
  }

  private startBehaviorAnalysis(): void {
    this.analysisTimer = setInterval(() => {
      if (this.currentSession) {
        this.analyzeBehavior();
      }
    }, this.config.behaviorAnalysisInterval);
  }

  private analyzeBehavior(): void {
    if (!this.currentSession) return;

    const stats = this.getBehaviorStats();
    this.onBehaviorUpdate?.(stats);

    const prediction = this.predictBehavior(stats);
    this.onPredictionUpdate?.(prediction);

    if (Date.now() - this.currentSession.lastActivityTime > this.config.sessionTimeout) {
      Logger.info(TAG, '会话超时，自动结束');
      this.endReadingSession();
    }
  }

  getBehaviorStats(): ReadingBehaviorStats {
    if (!this.currentSession) {
      return {
        currentBookId: null,
        currentChapterId: null,
        readingState: ReadingState.IDLE,
        sessionDuration: 0,
        effectiveReadingTime: 0,
        scrollCount: 0,
        averageScrollSpeed: 0,
        pauseCount: 0,
        totalPauseTime: 0,
        chapterChangeCount: 0,
        readingSpeed: 0,
        estimatedRemainingTime: 0,
        engagementScore: 0
      };
    }

    const session = this.currentSession;
    const now = Date.now();
    const sessionDuration = now - session.startTime;

    const totalPauseTime = session.pauseEvents.reduce((sum, e) => sum + e.duration, 0);
    const effectiveReadingTime = sessionDuration - totalPauseTime;

    const averageScrollSpeed = this.scrollVelocityBuffer.length > 0
      ? this.scrollVelocityBuffer.reduce((a, b) => a + b, 0) / this.scrollVelocityBuffer.length
      : 0;

    const readingSpeed = this.calculateReadingSpeed(session);

    const engagementScore = this.calculateEngagementScore(session, effectiveReadingTime, sessionDuration);

    return {
      currentBookId: session.bookId,
      currentChapterId: session.chapterId,
      readingState: this.readingState,
      sessionDuration,
      effectiveReadingTime,
      scrollCount: session.scrollEvents.length,
      averageScrollSpeed,
      pauseCount: session.pauseEvents.length,
      totalPauseTime,
      chapterChangeCount: this.chapterRecords.size,
      readingSpeed,
      estimatedRemainingTime: 0,
      engagementScore
    };
  }

  private calculateReadingSpeed(session: ReadingSession): number {
    if (session.scrollEvents.length < 3) return 0;

    const recentEvents = session.scrollEvents.slice(-10);
    const avgSpeed = recentEvents.reduce((sum, e) => sum + e.speed, 0) / recentEvents.length;

    this.readingSpeedBuffer.push(avgSpeed);
    if (this.readingSpeedBuffer.length > 5) {
      this.readingSpeedBuffer.shift();
    }

    return this.readingSpeedBuffer.reduce((a, b) => a + b, 0) / this.readingSpeedBuffer.length;
  }

  private calculateEngagementScore(session: ReadingSession, effectiveTime: number, totalTime: number): number {
    if (totalTime === 0) return 0;

    const timeScore = effectiveTime / totalTime;

    const scrollRegularity = this.calculateScrollRegularity(session.scrollEvents);

    const pauseScore = session.pauseEvents.length > 0
      ? Math.max(0, 1 - session.pauseEvents.length / 10)
      : 1;

    const directionChanges = this.countDirectionChanges(session.scrollEvents);
    const directionScore = Math.min(1, directionChanges / 5);

    const engagement = timeScore * 0.4 + scrollRegularity * 0.3 + pauseScore * 0.2 + directionScore * 0.1;

    return Math.min(1, Math.max(0, engagement));
  }

  private calculateScrollRegularity(events: ScrollEvent[]): number {
    if (events.length < 3) return 0;

    const intervals: number[] = [];
    for (let i = 1; i < events.length; i++) {
      intervals.push(events[i].timestamp - events[i - 1].timestamp);
    }

    const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
    const variance = intervals.reduce((sum, i) => sum + Math.pow(i - avgInterval, 2), 0) / intervals.length;
    const stdDev = Math.sqrt(variance);

    const regularity = Math.max(0, 1 - stdDev / avgInterval);
    return regularity;
  }

  private countDirectionChanges(events: ScrollEvent[]): number {
    let changes = 0;
    for (let i = 1; i < events.length; i++) {
      if (events[i].direction !== events[i - 1].direction) {
        changes++;
      }
    }
    return changes;
  }

  predictBehavior(stats: ReadingBehaviorStats): BehaviorPrediction {
    const likelyToContinue = this.predictLikelihoodToContinue(stats);
    const predictedNextChapter = this.predictNextChapter(stats);
    const estimatedReadDuration = this.estimateReadDuration(stats);
    const recommendedPreloadCount = this.calculatePreloadCount(stats, likelyToContinue);

    return {
      likelyToContinue,
      confidence: this.calculatePredictionConfidence(stats),
      predictedNextChapter,
      estimatedReadDuration,
      recommendedPreloadCount
    };
  }

  private predictLikelihoodToContinue(stats: ReadingBehaviorStats): boolean {
    if (stats.engagementScore < this.config.engagementThreshold) {
      return false;
    }

    if (stats.readingState === ReadingState.PAUSED && stats.totalPauseTime > 60000) {
      return false;
    }

    if (stats.scrollCount < 3 && stats.sessionDuration > 30000) {
      return false;
    }

    return true;
  }

  private predictNextChapter(stats: ReadingBehaviorStats): string | null {
    if (!stats.currentChapterId) return null;

    if (stats.readingState === ReadingState.CHAPTER_CHANGE) {
      return stats.currentChapterId;
    }

    if (stats.engagementScore > 0.7 && stats.readingSpeed > 0) {
      return null;
    }

    return null;
  }

  private estimateReadDuration(stats: ReadingBehaviorStats): number {
    if (stats.readingSpeed === 0) return 0;

    const avgChapterReadTime = this.calculateAverageChapterReadTime();
    return avgChapterReadTime * (1 - stats.engagementScore * 0.3);
  }

  private calculateAverageChapterReadTime(): number {
    const completedRecords = Array.from(this.chapterRecords.values()).filter(r => r.completed);

    if (completedRecords.length === 0) return 300000;

    const readTimes = completedRecords.map(r => (r.endTime ?? Date.now()) - r.startTime);
    return readTimes.reduce((a, b) => a + b, 0) / readTimes.length;
  }

  private calculatePreloadCount(stats: ReadingBehaviorStats, likelyToContinue: boolean): number {
    if (!likelyToContinue) return 0;

    if (stats.engagementScore > 0.8) {
      return 5;
    } else if (stats.engagementScore > 0.6) {
      return 3;
    } else if (stats.engagementScore > 0.4) {
      return 2;
    } else {
      return 1;
    }
  }

  private calculatePredictionConfidence(stats: ReadingBehaviorStats): number {
    let confidence = 0.5;

    if (stats.sessionDuration > 60000) confidence += 0.1;
    if (stats.sessionDuration > 180000) confidence += 0.1;
    if (stats.scrollCount > 10) confidence += 0.1;
    if (stats.chapterChangeCount > 1) confidence += 0.15;
    if (stats.engagementScore > 0.7) confidence += 0.05;

    return Math.min(1, confidence);
  }

  setOnStateChange(callback: (state: ReadingState, session: ReadingSession | null) => void): void {
    this.onStateChange = callback;
  }

  setOnBehaviorUpdate(callback: (stats: ReadingBehaviorStats) => void): void {
    this.onBehaviorUpdate = callback;
  }

  setOnPredictionUpdate(callback: (prediction: BehaviorPrediction) => void): void {
    this.onPredictionUpdate = callback;
  }

  private notifyStateChange(): void {
    this.onStateChange?.(this.readingState, this.currentSession);
  }

  private clearTimers(): void {
    if (this.pauseTimer) {
      clearTimeout(this.pauseTimer);
      this.pauseTimer = 0;
    }
  }

  setConfig(config: Partial<MonitorConfig>): void {
    if (config.scrollEventThreshold !== undefined) {
      this.config.scrollEventThreshold = config.scrollEventThreshold;
    }
    if (config.pauseDetectionDelay !== undefined) {
      this.config.pauseDetectionDelay = config.pauseDetectionDelay;
    }
    if (config.sessionTimeout !== undefined) {
      this.config.sessionTimeout = config.sessionTimeout;
    }
    if (config.engagementThreshold !== undefined) {
      this.config.engagementThreshold = config.engagementThreshold;
    }
    if (config.maxScrollEventsHistory !== undefined) {
      this.config.maxScrollEventsHistory = config.maxScrollEventsHistory;
    }
    if (config.behaviorAnalysisInterval !== undefined) {
      this.config.behaviorAnalysisInterval = config.behaviorAnalysisInterval;
    }
  }

  getCurrentState(): ReadingState {
    return this.readingState;
  }

  getCurrentSession(): ReadingSession | null {
    return this.currentSession;
  }

  getChapterRecord(chapterId: string): ChapterReadingRecord | undefined {
    return this.chapterRecords.get(chapterId);
  }

  destroy(): void {
    this.clearTimers();
    if (this.analysisTimer) {
      clearInterval(this.analysisTimer);
    }
    this.endReadingSession();
    this.chapterRecords.clear();
    Logger.info(TAG, '阅读行为监测器已销毁');
  }
}

export default ReadingBehaviorMonitor.getInstance();
