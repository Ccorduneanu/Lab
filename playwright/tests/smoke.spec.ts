import { test, expect } from '@playwright/test';

test('@smoke basic smoke test', async ({ page }) => {
  await page.goto('https://example.com');
  await expect(page).toHaveTitle(/Example/);
});
