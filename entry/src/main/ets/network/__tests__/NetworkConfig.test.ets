import {
  NetworkConfigManager,
  DEFAULT_NETWORK_CONFIG,
  AGGRESSIVE_NETWORK_CONFIG,
  CONSERVATIVE_NETWORK_CONFIG,
  type RetryConfig,
  type TimeoutConfig,
  type ImageScraperConfig,
  type SearchConfig,
  type NetworkConfig
} from '../../utils/NetworkConfig';

export class NetworkConfigTest {
  private passed: number = 0;
  private failed: number = 0;

  testGetInstance(): boolean {
    const instance1 = NetworkConfigManager.getInstance();
    const instance2 = NetworkConfigManager.getInstance();
    
    if (instance1 !== instance2) {
      console.error('❌ testGetInstance: should return same instance');
      this.failed++;
      return false;
    }
    
    console.log('✅ testGetInstance passed');
    this.passed++;
    return true;
  }

  testDefaultConfig(): boolean {
    const config: NetworkConfig = DEFAULT_NETWORK_CONFIG;
    
    if (config.retry.maxRetries !== 2) {
      console.error('❌ testDefaultConfig: maxRetries should be 2');
      this.failed++;
      return false;
    }
    
    if (config.timeout.connectTimeout !== 8000) {
      console.error('❌ testDefaultConfig: connectTimeout should be 8000');
      this.failed++;
      return false;
    }
    
    if (config.imageScraper.maxConcurrentDownloads !== 3) {
      console.error('❌ testDefaultConfig: maxConcurrentDownloads should be 3');
      this.failed++;
      return false;
    }
    
    if (config.search.maxConcurrent !== 5) {
      console.error('❌ testDefaultConfig: search maxConcurrent should be 5');
      this.failed++;
      return false;
    }
    
    console.log('✅ testDefaultConfig passed');
    this.passed++;
    return true;
  }

  testAggressiveConfig(): boolean {
    const config: NetworkConfig = AGGRESSIVE_NETWORK_CONFIG;
    
    if (config.retry.maxRetries !== 1) {
      console.error('❌ testAggressiveConfig: maxRetries should be 1');
      this.failed++;
      return false;
    }
    
    if (config.timeout.connectTimeout !== 5000) {
      console.error('❌ testAggressiveConfig: connectTimeout should be 5000');
      this.failed++;
      return false;
    }
    
    if (config.imageScraper.maxConcurrentDownloads !== 5) {
      console.error('❌ testAggressiveConfig: maxConcurrentDownloads should be 5');
      this.failed++;
      return false;
    }
    
    console.log('✅ testAggressiveConfig passed');
    this.passed++;
    return true;
  }

  testConservativeConfig(): boolean {
    const config: NetworkConfig = CONSERVATIVE_NETWORK_CONFIG;
    
    if (config.retry.maxRetries !== 3) {
      console.error('❌ testConservativeConfig: maxRetries should be 3');
      this.failed++;
      return false;
    }
    
    if (config.timeout.connectTimeout !== 10000) {
      console.error('❌ testConservativeConfig: connectTimeout should be 10000');
      this.failed++;
      return false;
    }
    
    if (config.imageScraper.maxConcurrentDownloads !== 2) {
      console.error('❌ testConservativeConfig: maxConcurrentDownloads should be 2');
      this.failed++;
      return false;
    }
    
    console.log('✅ testConservativeConfig passed');
    this.passed++;
    return true;
  }

  testGetRetryConfig(): boolean {
    const manager = NetworkConfigManager.getInstance();
    const retryConfig: RetryConfig = manager.getRetryConfig();
    
    if (retryConfig.maxRetries === undefined) {
      console.error('❌ testGetRetryConfig: maxRetries should be defined');
      this.failed++;
      return false;
    }
    
    if (retryConfig.baseDelay === undefined) {
      console.error('❌ testGetRetryConfig: baseDelay should be defined');
      this.failed++;
      return false;
    }
    
    console.log('✅ testGetRetryConfig passed');
    this.passed++;
    return true;
  }

  testGetTimeoutConfig(): boolean {
    const manager = NetworkConfigManager.getInstance();
    const timeoutConfig: TimeoutConfig = manager.getTimeoutConfig();
    
    if (timeoutConfig.connectTimeout === undefined) {
      console.error('❌ testGetTimeoutConfig: connectTimeout should be defined');
      this.failed++;
      return false;
    }
    
    if (timeoutConfig.readTimeout === undefined) {
      console.error('❌ testGetTimeoutConfig: readTimeout should be defined');
      this.failed++;
      return false;
    }
    
    console.log('✅ testGetTimeoutConfig passed');
    this.passed++;
    return true;
  }

  testGetImageScraperConfig(): boolean {
    const manager = NetworkConfigManager.getInstance();
    const imageConfig: ImageScraperConfig = manager.getImageScraperConfig();
    
    if (imageConfig.downloadTimeout === undefined) {
      console.error('❌ testGetImageScraperConfig: downloadTimeout should be defined');
      this.failed++;
      return false;
    }
    
    if (imageConfig.minImageSize === undefined) {
      console.error('❌ testGetImageScraperConfig: minImageSize should be defined');
      this.failed++;
      return false;
    }
    
    if (imageConfig.maxImageSize === undefined) {
      console.error('❌ testGetImageScraperConfig: maxImageSize should be defined');
      this.failed++;
      return false;
    }
    
    if (!Array.isArray(imageConfig.preferredFormats)) {
      console.error('❌ testGetImageScraperConfig: preferredFormats should be array');
      this.failed++;
      return false;
    }
    
    console.log('✅ testGetImageScraperConfig passed');
    this.passed++;
    return true;
  }

  testGetSearchConfig(): boolean {
    const manager = NetworkConfigManager.getInstance();
    const searchConfig: SearchConfig = manager.getSearchConfig();
    
    if (searchConfig.maxConcurrent === undefined) {
      console.error('❌ testGetSearchConfig: maxConcurrent should be defined');
      this.failed++;
      return false;
    }
    
    if (searchConfig.timeout === undefined) {
      console.error('❌ testGetSearchConfig: timeout should be defined');
      this.failed++;
      return false;
    }
    
    console.log('✅ testGetSearchConfig passed');
    this.passed++;
    return true;
  }

  testIsRetryableError(): boolean {
    const manager = NetworkConfigManager.getInstance();
    
    if (!manager.isRetryableError('timeout')) {
      console.error('❌ testIsRetryableError: timeout should be retryable');
      this.failed++;
      return false;
    }
    
    if (!manager.isRetryableError('network')) {
      console.error('❌ testIsRetryableError: network should be retryable');
      this.failed++;
      return false;
    }
    
    if (manager.isRetryableError('unknown_type')) {
      console.error('❌ testIsRetryableError: unknown_type should not be retryable');
      this.failed++;
      return false;
    }
    
    console.log('✅ testIsRetryableError passed');
    this.passed++;
    return true;
  }

  testIsRetryableStatusCode(): boolean {
    const manager = NetworkConfigManager.getInstance();
    
    if (!manager.isRetryableError('http', 500)) {
      console.error('❌ testIsRetryableStatusCode: 500 should be retryable');
      this.failed++;
      return false;
    }
    
    if (!manager.isRetryableError('http', 502)) {
      console.error('❌ testIsRetryableStatusCode: 502 should be retryable');
      this.failed++;
      return false;
    }
    
    if (manager.isRetryableError('http', 200)) {
      console.error('❌ testIsRetryableStatusCode: 200 should not be retryable');
      this.failed++;
      return false;
    }
    
    console.log('✅ testIsRetryableStatusCode passed');
    this.passed++;
    return true;
  }

  testUpdateImageScraperConfig(): boolean {
    const manager = NetworkConfigManager.getInstance();

    const originalConfig: ImageScraperConfig = manager.getImageScraperConfig();
    const originalTimeout: number = originalConfig.downloadTimeout;

    manager.updateImageScraperConfig({ downloadTimeout: 60000 });

    const updatedConfig: ImageScraperConfig = manager.getImageScraperConfig();
    
    if (updatedConfig.downloadTimeout !== 60000) {
      console.error('❌ testUpdateImageScraperConfig: downloadTimeout should be updated');
      this.failed++;
      manager.updateImageScraperConfig({ downloadTimeout: originalTimeout });
      return false;
    }
    
    manager.updateImageScraperConfig({ downloadTimeout: originalTimeout });
    
    console.log('✅ testUpdateImageScraperConfig passed');
    this.passed++;
    return true;
  }

  testUpdateSearchConfig(): boolean {
    const manager = NetworkConfigManager.getInstance();

    const originalConfig: SearchConfig = manager.getSearchConfig();
    const originalConcurrent: number = originalConfig.maxConcurrent;

    manager.updateSearchConfig({ maxConcurrent: 10 });

    const updatedConfig: SearchConfig = manager.getSearchConfig();
    
    if (updatedConfig.maxConcurrent !== 10) {
      console.error('❌ testUpdateSearchConfig: maxConcurrent should be updated');
      this.failed++;
      manager.updateSearchConfig({ maxConcurrent: originalConcurrent });
      return false;
    }
    
    manager.updateSearchConfig({ maxConcurrent: originalConcurrent });
    
    console.log('✅ testUpdateSearchConfig passed');
    this.passed++;
    return true;
  }

  testSetConfig(): boolean {
    const manager = NetworkConfigManager.getInstance();

    const originalConfig: NetworkConfig = manager.getConfig();

    manager.setConfig(AGGRESSIVE_NETWORK_CONFIG);

    const newConfig: NetworkConfig = manager.getConfig();
    
    if (newConfig.retry.maxRetries !== 1) {
      console.error('❌ testSetConfig: should use aggressive config');
      this.failed++;
      manager.setConfig(originalConfig);
      return false;
    }
    
    manager.setConfig(originalConfig);
    
    console.log('✅ testSetConfig passed');
    this.passed++;
    return true;
  }

  async runAllTests(): Promise<boolean> {
    console.log('🚀 Starting NetworkConfig tests...');
    
    this.testGetInstance();
    this.testDefaultConfig();
    this.testAggressiveConfig();
    this.testConservativeConfig();
    this.testGetRetryConfig();
    this.testGetTimeoutConfig();
    this.testGetImageScraperConfig();
    this.testGetSearchConfig();
    this.testIsRetryableError();
    this.testIsRetryableStatusCode();
    this.testUpdateImageScraperConfig();
    this.testUpdateSearchConfig();
    this.testSetConfig();
    
    const total = this.passed + this.failed;
    console.log(`\n📊 Test Results: ${this.passed}/${total} tests passed`);
    
    if (this.failed === 0) {
      console.log('✅ All NetworkConfig tests passed!');
      return true;
    } else {
      console.log('❌ Some NetworkConfig tests failed');
      return false;
    }
  }
}

const networkConfigTest = new NetworkConfigTest();
export default networkConfigTest;
