/**
 * AstroRead 代码风格规范
 * 基于 ArkTS 最佳实践
 */

module.exports = {
  root: true,
  env: {
    es2021: true
  },
  extends: [
    'eslint:recommended'
  ],
  parserOptions: {
    ecmaVersion: 2021,
    sourceType: 'module'
  },
  rules: {
    // ========== 命名规范 ==========

    // 变量使用 camelCase
    'camelcase': ['error', {
      properties: 'always',
      ignoreDestructuring: false,
      allow: [] // 允许的例外，如 snake_case 数据库字段
    }],

    // 类和接口使用 PascalCase
    // 注意：ArkTS 接口不使用 I 前缀
    // 正确: interface HttpClient { }
    // 错误: interface IHttpClient { }

    // 常量使用 UPPER_SNAKE_CASE
    // 正确: const MAX_RETRY_COUNT = 3;
    // 错误: const maxRetryCount = 3;

    // 私有成员使用下划线前缀
    // 正确: private _instance: MyClass | null = null;
    // 错误: private instance: MyClass | null = null;

    // ========== 类型规范 ==========

    // 禁止使用 any
    '@typescript-eslint/no-explicit-any': 'error',

    // 必须显式返回类型
    '@typescript-eslint/explicit-function-return-type': ['warn', {
      allowExpressions: true,
      allowTypedFunctionExpressions: true
    }],

    // ========== 代码质量 ==========

    // 禁止未使用的变量
    'no-unused-vars': ['error', {
      argsIgnorePattern: '^_',
      varsIgnorePattern: '^_'
    }],

    // 禁止重复定义
    'no-redeclare': 'error',

    // 禁止空块（除了 catch）
    'no-empty': ['error', { allowEmptyCatch: true }],

    // 禁止 eval
    'no-eval': 'error',

    // 禁止 with
    'no-with': 'error',

    // ========== 最佳实践 ==========

    // 使用 === 而不是 ==
    'eqeqeq': ['error', 'always', { null: 'ignore' }],

    // 禁止 var，使用 let/const
    'no-var': 'error',

    // 优先使用 const
    'prefer-const': ['error', {
      destructuring: 'any',
      ignoreReadBeforeAssign: false
    }],

    // 禁止不必要的 return
    'no-useless-return': 'error',

    // ========== 代码风格 ==========

    // 缩进使用 2 空格
    'indent': ['error', 2, {
      SwitchCase: 1,
      VariableDeclarator: 1,
      outerIIFEBody: 1,
      MemberExpression: 1,
      FunctionDeclaration: { parameters: 1, body: 1 },
      FunctionExpression: { parameters: 1, body: 1 },
      CallExpression: { arguments: 1 },
      ArrayExpression: 1,
      ObjectExpression: 1
    }],

    // 使用单引号
    'quotes': ['error', 'single', {
      avoidEscape: true,
      allowTemplateLiterals: true
    }],

    // 不使用分号
    'semi': ['error', 'never', {
      beforeStatementContinuationChars: 'never'
    }],

    // 逗号后加空格
    'comma-spacing': ['error', { before: false, after: true }],

    // 对象字面量冒号后加空格
    'key-spacing': ['error', { beforeColon: false, afterColon: true }],

    // 关键字前后加空格
    'keyword-spacing': ['error', { before: true, after: true }],

    // 函数括号前加空格
    'space-before-function-paren': ['error', {
      anonymous: 'always',
      named: 'never',
      asyncArrow: 'always'
    }],

    // 操作符前后加空格
    'space-infix-ops': 'error',

    // 箭头函数箭头前后加空格
    'arrow-spacing': ['error', { before: true, after: true }],

    // ========== 注释规范 ==========

    // 注释后加空格
    'spaced-comment': ['error', 'always', {
      line: { markers: ['/'] },
      block: { markers: ['*'], exceptions: ['*'] }
    }],

    // ========== 文件规范 ==========

    // 文件末尾换行
    'eol-last': ['error', 'always'],

    // 禁止尾随空格
    'no-trailing-spaces': 'error',

    // 禁止多行空行
    'no-multiple-empty-lines': ['error', { max: 2, maxEOF: 1 }]
  },

  overrides: [
    {
      // 测试文件规则放宽
      files: ['**/*.test.ets', '**/*.spec.ets'],
      rules: {
        '@typescript-eslint/no-explicit-any': 'off',
        'no-unused-vars': 'off'
      }
    }
  ]
}
