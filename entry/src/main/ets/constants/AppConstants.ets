/**
 * AppConstants - 应用全局常量定义
 * 集中管理所有魔法数字和字符串常量
 */

export interface TimeConstantsType {
  SECOND: number;
  MINUTE: number;
  FIVE_MINUTES: number;
  FIFTEEN_MINUTES: number;
  THIRTY_MINUTES: number;
  HOUR: number;
  DAY: number;
}

export const TimeConstants: TimeConstantsType = {
  SECOND: 1000,
  MINUTE: 60 * 1000,
  FIVE_MINUTES: 5 * 60 * 1000,
  FIFTEEN_MINUTES: 15 * 60 * 1000,
  THIRTY_MINUTES: 30 * 60 * 1000,
  HOUR: 60 * 60 * 1000,
  DAY: 24 * 60 * 60 * 1000,
};

export interface CacheConstantsType {
  DEFAULT_MAX_SIZE: number;
  DEFAULT_TTL: number;
  SEARCH_CACHE_SIZE: number;
  PARSE_CACHE_SIZE: number;
  REGEX_CACHE_SIZE: number;
  CLEANUP_INTERVAL: number;
  SEARCH_CLEANUP_INTERVAL: number;
}

export const CacheConstants: CacheConstantsType = {
  DEFAULT_MAX_SIZE: 100,
  DEFAULT_TTL: TimeConstants.FIVE_MINUTES,
  SEARCH_CACHE_SIZE: 50,
  PARSE_CACHE_SIZE: 200,
  REGEX_CACHE_SIZE: 100,
  CLEANUP_INTERVAL: 30 * 1000,
  SEARCH_CLEANUP_INTERVAL: TimeConstants.MINUTE,
};

export interface SearchConstantsType {
  DEFAULT_PAGE_SIZE: number;
  DEFAULT_MAX_RESULTS_PER_SOURCE: number;
  DEFAULT_MAX_TOTAL_RESULTS: number;
  MIN_RESULTS_PER_SOURCE: number;
  MAX_RESULTS_PER_SOURCE: number;
  MIN_TOTAL_RESULTS: number;
  MAX_TOTAL_RESULTS: number;
  DEFAULT_REQUEST_INTERVAL: number;
  THROTTLE_MS: number;
  DEFAULT_TIMEOUT: number;
  MAX_QUERY_LENGTH: number;
  MAX_INTRO_LENGTH: number;
  MAX_BOOK_NAME_LENGTH: number;
  MAX_INTRO_VALIDATION_LENGTH: number;
}

export const SearchConstants: SearchConstantsType = {
  DEFAULT_PAGE_SIZE: 15,
  DEFAULT_MAX_RESULTS_PER_SOURCE: 20,
  DEFAULT_MAX_TOTAL_RESULTS: 200,
  MIN_RESULTS_PER_SOURCE: 5,
  MAX_RESULTS_PER_SOURCE: 100,
  MIN_TOTAL_RESULTS: 50,
  MAX_TOTAL_RESULTS: 500,
  DEFAULT_REQUEST_INTERVAL: 500,
  THROTTLE_MS: 200,
  DEFAULT_TIMEOUT: 10000,
  MAX_QUERY_LENGTH: 200,
  MAX_INTRO_LENGTH: 200,
  MAX_BOOK_NAME_LENGTH: 100,
  MAX_INTRO_VALIDATION_LENGTH: 500,
};

export interface ContentConstantsType {
  DEFAULT_MAX_LENGTH: number;
  LOG_MAX_LENGTH: number;
  DEBUG_HTML_LENGTH: number;
  ERROR_HTML_LENGTH: number;
  GARBAGE_THRESHOLD_HIGH: number;
  GARBAGE_THRESHOLD_LOW: number;
}

export const ContentConstants: ContentConstantsType = {
  DEFAULT_MAX_LENGTH: 500,
  LOG_MAX_LENGTH: 1000,
  DEBUG_HTML_LENGTH: 500,
  ERROR_HTML_LENGTH: 200,
  GARBAGE_THRESHOLD_HIGH: 0.3,
  GARBAGE_THRESHOLD_LOW: 0.1,
};

export interface HttpStatusCodesType {
  OK: number;
  UNAUTHORIZED: number;
  FORBIDDEN: number;
  NOT_FOUND: number;
  SERVER_ERROR: number;
  SERVICE_UNAVAILABLE: number;
}

export const HttpStatusCodes: HttpStatusCodesType = {
  OK: 200,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
};

export interface DatabaseConstantsType {
  MAX_IDENTIFIER_LENGTH: number;
  BATCH_INSERT_SIZE: number;
  MAX_CONNECTIONS: number;
}

export const DatabaseConstants: DatabaseConstantsType = {
  MAX_IDENTIFIER_LENGTH: 128,
  BATCH_INSERT_SIZE: 100,
  MAX_CONNECTIONS: 10,
};

export interface SecurityConstantsType {
  MAX_PATH_DEPTH: number;
  MAX_FILE_SIZE: number;
  MAX_REGEX_EXECUTION_TIME: number;
  MAX_REGEX_COMPLEXITY: number;
  MIN_PASSWORD_LENGTH: number;
  TOKEN_EXPIRY_HOURS: number;
}

export const SecurityConstants: SecurityConstantsType = {
  MAX_PATH_DEPTH: 10,
  MAX_FILE_SIZE: 10 * 1024 * 1024,
  MAX_REGEX_EXECUTION_TIME: 1000,
  MAX_REGEX_COMPLEXITY: 100,
  MIN_PASSWORD_LENGTH: 8,
  TOKEN_EXPIRY_HOURS: 24,
};

export interface RetryConstantsType {
  DEFAULT_RETRY_COUNT: number;
  DEFAULT_RETRY_DELAY: number;
  MAX_RETRY_COUNT: number;
  BACKOFF_BASE: number;
}

export const RetryConstants: RetryConstantsType = {
  DEFAULT_RETRY_COUNT: 3,
  DEFAULT_RETRY_DELAY: 1000,
  MAX_RETRY_COUNT: 5,
  BACKOFF_BASE: 2,
};

export interface NetworkConstantsType {
  DEFAULT_TIMEOUT: number;
  CONNECT_TIMEOUT: number;
  READ_TIMEOUT: number;
  MAX_CONCURRENT_REQUESTS: number;
  RATE_LIMIT_WINDOW: number;
  MAX_REQUEST_RATE: number;
}

export const NetworkConstants: NetworkConstantsType = {
  DEFAULT_TIMEOUT: 10000,
  CONNECT_TIMEOUT: 5000,
  READ_TIMEOUT: 30000,
  MAX_CONCURRENT_REQUESTS: 10,
  RATE_LIMIT_WINDOW: 1000,
  MAX_REQUEST_RATE: 10,
};

export interface EncodingsType {
  UTF8: string;
  GBK: string;
  GB2312: string;
  LATIN1: string;
}

export interface FileConstantsType {
  MAX_FILE_SIZE_MB: number;
  SUPPORTED_IMAGE_FORMATS: string[];
  SUPPORTED_SOURCE_FORMATS: string[];
  ENCODINGS: EncodingsType;
}

export const FileConstants: FileConstantsType = {
  MAX_FILE_SIZE_MB: 10,
  SUPPORTED_IMAGE_FORMATS: ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
  SUPPORTED_SOURCE_FORMATS: ['.json', '.txt'],
  ENCODINGS: {
    UTF8: 'utf-8',
    GBK: 'gbk',
    GB2312: 'gb2312',
    LATIN1: 'latin1',
  },
};

export interface LogLevelsType {
  DEBUG: string;
  INFO: string;
  WARN: string;
  ERROR: string;
}

export interface LogConstantsType {
  MAX_LOG_FILE_SIZE: number;
  MAX_LOG_FILES: number;
  LEVELS: LogLevelsType;
}

export const LogConstants: LogConstantsType = {
  MAX_LOG_FILE_SIZE: 10,
  MAX_LOG_FILES: 5,
  LEVELS: {
    DEBUG: 'DEBUG',
    INFO: 'INFO',
    WARN: 'WARN',
    ERROR: 'ERROR',
  },
};

export interface PaginationConstantsType {
  DEFAULT_PAGE: number;
  DEFAULT_PAGE_SIZE: number;
  MAX_PAGE_SIZE: number;
  MIN_PAGE_SIZE: number;
}

export const PaginationConstants: PaginationConstantsType = {
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_SIZE: 15,
  MAX_PAGE_SIZE: 100,
  MIN_PAGE_SIZE: 5,
};

export interface BookSourceConstantsType {
  MAX_NAME_LENGTH: number;
  MAX_URL_LENGTH: number;
  MAX_SOURCES: number;
  DEFAULT_WEIGHT: number;
  MIN_WEIGHT: number;
  MAX_WEIGHT: number;
}

export const BookSourceConstants: BookSourceConstantsType = {
  MAX_NAME_LENGTH: 100,
  MAX_URL_LENGTH: 500,
  MAX_SOURCES: 1000,
  DEFAULT_WEIGHT: 100,
  MIN_WEIGHT: 1,
  MAX_WEIGHT: 1000,
};
