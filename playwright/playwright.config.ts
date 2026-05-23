import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  expect: { timeout: 5000 },
  reporter: [['list'], ['junit', { outputFile: 'results/results.xml' }], ['html', { outputFolder: 'playwright-report' }]],
  use: { headless: true }
});
