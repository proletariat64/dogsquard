import './style.css';

type Priority = 'low' | 'medium' | 'high';
type Status = 'open' | 'in_progress' | 'done';

type Task = {
  id: string;
  title: string;
  description: string;
  priority: Priority;
  status: Status;
  created_at: string;
  updated_at: string;
};

type ErrorResponse = {
  error?: {
    code?: string;
    message?: string;
  };
};

const apiBase = (import.meta.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:8080').replace(/\/$/, '');

const app = requiredElement<HTMLDivElement>('#app');

app.innerHTML = `
  <section class="shell">
    <header class="page-header">
      <div>
        <p class="eyebrow">Dogsquard example app</p>
        <h1>Internal Task Intake</h1>
      </div>
      <button class="secondary" id="refreshTasks" type="button">Refresh</button>
    </header>

    <section class="panel">
      <h2>Create task</h2>
      <form id="taskForm" novalidate>
        <label>
          Title
          <input id="title" name="title" autocomplete="off" />
        </label>
        <label>
          Description
          <textarea id="description" name="description" rows="3"></textarea>
        </label>
        <label>
          Priority
          <select id="priority" name="priority">
            <option value="low">Low</option>
            <option value="medium" selected>Medium</option>
            <option value="high">High</option>
          </select>
        </label>
        <p class="error" id="formError" role="alert"></p>
        <button type="submit">Create task</button>
      </form>
    </section>

    <section class="panel">
      <div class="section-heading">
        <h2>Dashboard</h2>
        <span id="taskCount">0 tasks</span>
      </div>
      <p class="status-message" id="taskStatus" role="status"></p>
      <div id="taskList"></div>
    </section>
  </section>
`;

const taskForm = requiredElement<HTMLFormElement>('#taskForm');
const taskList = requiredElement<HTMLDivElement>('#taskList');
const formError = requiredElement<HTMLParagraphElement>('#formError');
const taskCount = requiredElement<HTMLSpanElement>('#taskCount');
const taskStatus = requiredElement<HTMLParagraphElement>('#taskStatus');
const refreshTasks = requiredElement<HTMLButtonElement>('#refreshTasks');

let tasks: Task[] = [];
let isLoading = false;

taskForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  clearError();

  const formData = new FormData(taskForm);
  const title = String(formData.get('title') ?? '');
  const description = String(formData.get('description') ?? '');
  const priority = String(formData.get('priority') ?? 'medium') as Priority;

  try {
    await apiRequest<Task>('/api/tasks', {
      method: 'POST',
      body: JSON.stringify({ title, description, priority }),
    });
    taskForm.reset();
    await loadTasks();
  } catch (error) {
    showError(error);
  }
});

refreshTasks.addEventListener('click', () => {
  void loadTasks();
});

async function loadTasks(): Promise<void> {
  isLoading = true;
  renderTasks();
  try {
    tasks = await apiRequest<Task[]>('/api/tasks');
    clearError();
    taskStatus.textContent = '';
    taskStatus.classList.remove('error');
    renderTasks();
  } catch (error) {
    taskStatus.classList.add('error');
    taskStatus.textContent = errorMessage(error);
    showError(error);
  } finally {
    isLoading = false;
    renderTasks();
  }
}

function renderTasks(): void {
  taskCount.textContent = `${tasks.length} ${tasks.length === 1 ? 'task' : 'tasks'}`;

  if (isLoading) {
    taskList.innerHTML = `<p class="empty">Loading tasks...</p>`;
    return;
  }

  if (tasks.length === 0) {
    taskList.innerHTML = `<p class="empty">No tasks yet. Create the first intake item.</p>`;
    return;
  }

  const rows = tasks
    .map(
      (task) => `
        <tr>
          <td>
            <strong>${escapeHTML(task.title)}</strong>
            <small>${escapeHTML(task.description || 'No description')}</small>
          </td>
          <td>${escapeHTML(task.priority)}</td>
          <td>
            <select data-action="status" data-id="${escapeHTML(task.id)}">
              ${statusOption(task.status, 'open', 'Open')}
              ${statusOption(task.status, 'in_progress', 'In progress')}
              ${statusOption(task.status, 'done', 'Done')}
            </select>
          </td>
          <td>
            <button class="danger" data-action="delete" data-id="${escapeHTML(task.id)}" type="button">Delete</button>
          </td>
        </tr>
      `,
    )
    .join('');

  taskList.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Task</th>
          <th>Priority</th>
          <th>Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;

  taskList.querySelectorAll<HTMLSelectElement>('select[data-action="status"]').forEach((select) => {
    select.addEventListener('change', async () => {
      const id = select.dataset.id;
      if (!id) return;
      try {
        await apiRequest<Task>(`/api/tasks/${encodeURIComponent(id)}`, {
          method: 'PATCH',
          body: JSON.stringify({ status: select.value }),
        });
        await loadTasks();
      } catch (error) {
        showError(error);
      }
    });
  });

  taskList.querySelectorAll<HTMLButtonElement>('button[data-action="delete"]').forEach((button) => {
    button.addEventListener('click', async () => {
      const id = button.dataset.id;
      if (!id) return;
      try {
        await apiRequest<void>(`/api/tasks/${encodeURIComponent(id)}`, { method: 'DELETE' });
        await loadTasks();
      } catch (error) {
        showError(error);
      }
    });
  });
}

function statusOption(current: Status, value: Status, label: string): string {
  return `<option value="${value}" ${current === value ? 'selected' : ''}>${label}</option>`;
}

async function apiRequest<T>(path: string, init: RequestInit = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${apiBase}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...init.headers,
      },
    });
  } catch {
    throw new Error(`Cannot reach API at ${apiBase}`);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  const data = (await readJSON(response)) as T | ErrorResponse;

  if (!response.ok) {
    const error = data as ErrorResponse;
    throw new Error(error.error?.message || `Request failed with status ${response.status}`);
  }

  return data as T;
}

function showError(error: unknown): void {
  formError.textContent = errorMessage(error);
}

function clearError(): void {
  formError.textContent = '';
}

async function readJSON(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    throw new Error(`API returned non-JSON response with status ${response.status}`);
  }
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unexpected error';
}

function escapeHTML(value: string): string {
  return value.replace(/[&<>"']/g, (char) => {
    const entities: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    return entities[char];
  });
}

function requiredElement<T extends Element>(selector: string): T {
  const element = document.querySelector<T>(selector);
  if (!element) {
    throw new Error(`Required element not found: ${selector}`);
  }
  return element;
}

void loadTasks();
