import { expect, test } from '@playwright/test';

test('Internal Task Intake minimal smoke @smoke', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByRole('heading', { name: 'Internal Task Intake' })).toBeVisible();
  await expect(page.getByText('No tasks yet. Create the first intake item.')).toBeVisible();

  await page.getByLabel('Title').fill('Smoke task');
  await page.getByLabel('Description').fill('Created by Playwright smoke');
  await page.getByLabel('Priority').selectOption('high');
  await page.getByRole('button', { name: 'Create task' }).click();

  await expect(page.getByRole('cell', { name: /Smoke task/ })).toBeVisible();
  await expect(page.getByRole('cell', { name: 'high' })).toBeVisible();

  await page.getByLabel('Title').fill('');
  await page.getByRole('button', { name: 'Create task' }).click();

  await expect(page.getByRole('alert')).toContainText('title is required');
});
