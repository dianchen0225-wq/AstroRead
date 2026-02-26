/*
 * Copyright (c) 2025 AstroRead Project
 * AstroRead - 纯血鸿蒙 OpenHarmony Next 阅读器应用
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * 页边距配置
 */
export interface MarginsConfig {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

export interface ReadConfig {
  fontSize: number;
  lineSpacing: number;
  letterSpacing: number;
  pageTurnMode: 'cover' | 'slide' | 'scroll' | 'simulation';
  backgroundColor: string;
  textColor: string;
  isNightMode: boolean;
  brightness: number;
  autoScroll: boolean;
  scrollSpeed: number;
  fontFamily: string;
  margins: MarginsConfig;
  volumeKeyPageTurn: boolean;
  clickPageTurn: boolean;
}

/**
 * 默认页边距配置
 */
const DEFAULT_MARGINS: MarginsConfig = {
  top: 20,
  bottom: 20,
  left: 20,
  right: 20,
};

/**
 * 默认阅读配置
 */
export const DEFAULT_READ_CONFIG: ReadConfig = {
  fontSize: 18,
  lineSpacing: 1.5,
  letterSpacing: 0,
  pageTurnMode: 'cover',
  backgroundColor: '#FFFFFF',
  textColor: '#333333',
  isNightMode: false,
  brightness: 0.5,
  autoScroll: false,
  scrollSpeed: 50,
  fontFamily: 'HarmonyOS Sans',
  margins: DEFAULT_MARGINS,
  volumeKeyPageTurn: true,
  clickPageTurn: true
};
