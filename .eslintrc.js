/**
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module.exports = {
  ignorePatterns: [
    // 忽略预览缓存目录
    '**/.preview/**',
    // 忽略构建缓存目录
    '**/build/**',
    '**/.hvigor/**',
    // 忽略 node_modules
    '**/node_modules/**',
    '**/oh_modules/**',
    // 忽略编译产物
    '**/*.protoBin',
    '**/*.ts',
    // 只检查 .ets 源文件
  ],
  overrides: [
    {
      files: ['**/*.ets'],
      rules: {
        // 版权信息检查
        'copyright-information-missing': 'off',
      }
    }
  ]
};
