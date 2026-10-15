# API Layer Rule

Apply this rule when adding API integration or data fetching.

## Shared Axios Client

Create one shared client in `src/lib/api/client.ts`.

```ts
import axios from "axios";

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 15000,
});
```

Base URL comes from environment variables. Do not hardcode environment-specific URLs in components.

## Interceptors

Centralize auth and error normalization.

```ts
apiClient.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      useAuthStore.getState().logout();
    }
    return Promise.reject(normalizeApiError(error));
  },
);
```

Adapt store imports to the project.

## Feature API Files

Each feature owns its resource API functions.

```ts
import { apiClient } from "@/lib/api/client";
import type { CreateProductInput, Product } from "../types";

export const productsApi = {
  list: async (): Promise<Product[]> => {
    const { data } = await apiClient.get<Product[]>("/products");
    return data;
  },

  create: async (input: CreateProductInput): Promise<Product> => {
    const { data } = await apiClient.post<Product>("/products", input);
    return data;
  },
};
```

Every API function must type its input and return value.

## Hooks Wrap API Calls

Components should not call API functions directly. Use feature hooks for loading, error, empty, and data state.

If caching, pagination, invalidation, or refetching becomes complex, propose TanStack Query explicitly instead of silently adding it.

## Rules

- Components and hooks do not import Axios directly.
- Components do not contain endpoint URL strings.
- Feature API files own endpoint paths.
- Auth and 401 handling live in interceptors.
- Error UI uses a normalized error shape.
