/**
 * HeartLock 设计 Tokens
 * 与 resources/base/element/{color,float,string}.json 保持一致
 */

// ── 颜色 ──
export const Colors = {
  bgPrimary: '#0D0D0D',
  bgCard: '#1A1A1A',
  bgElevated: '#222222',
  divider: '#2A2A2A',
  textPrimary: '#FFFFFF',
  textSecondary: '#99FFFFFF',
  textTertiary: '#66FFFFFF',
  accent: '#D4A574',
  accentLight: '#E8C49A',
  accentDim: '#A88050',
  danger: '#FF4444',
  disabled: '#33FFFFFF',
  matchedBorder: '#D4A574',
} as const;

// ── 间距 ──
export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
} as const;

// ── 字号 ──
export const FontSize = {
  title: 24,
  subtitle: 18,
  body: 16,
  caption: 13,
  small: 11,
} as const;

// ── 圆角 ──
export const Radius = {
  card: 12,
  button: 8,
  pill: 24,
} as const;

// ── 图标 ──
export const IconSize = {
  sm: 20,
  md: 24,
  lg: 32,
  xl: 48,
  xxl: 64,
} as const;

// ── 按钮高度 ──
export const ButtonHeight = 48 as const;
