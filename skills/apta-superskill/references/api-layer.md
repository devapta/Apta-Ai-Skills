# API Layer Pattern

Use this guide before wiring data fetching or API integration.

## Axios Client

Create one shared Axios instance in `src/lib/api/client.ts`.

```ts
import axios from "axios";

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 15000,
});
```

Base URL must come from an environment variable. Do not hardcode environment-specific URLs in components.

## Interceptors

Attach auth and response normalization in one place.

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

Adjust auth store imports to match the actual project.

## One Resource File Per Feature

Feature API calls live under that feature.

Example: `src/features/products/api/products.api.ts`

```ts
import { apiClient } from "@/lib/api/client";
import type { CreateProductInput, Product } from "../types";

export const productsApi = {
  list: async (): Promise<Product[]> => {
    const { data } = await apiClient.get<Product[]>("/products");
    return data;
  },

  getById: async (id: string): Promise<Product> => {
    const { data } = await apiClient.get<Product>(`/products/${id}`);
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

Components should not call API functions directly. Use feature hooks to manage loading, error, empty, and data state.

```tsx
export function useProductList() {
  const [data, setData] = useState<Product[] | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<ApiError | null>(null);

  useEffect(() => {
    let cancelled = false;

    setIsLoading(true);
    productsApi
      .list()
      .then((result) => !cancelled && setData(result))
      .catch((err) => !cancelled && setError(err))
      .finally(() => !cancelled && setIsLoading(false));

    return () => {
      cancelled = true;
    };
  }, []);

  return { data, isLoading, error };
}
```

If a project has complex caching, pagination, invalidation, or refetching needs, propose TanStack Query as an explicit stack decision.

## Error Shape

Normalize API errors into one shared shape.

```ts
export interface ApiError {
  message: string;
  status?: number;
  code?: string;
}

function normalizeApiError(error: unknown): ApiError {
  if (axios.isAxiosError(error)) {
    return {
      message:
        error.response?.data?.message ??
        "Something went wrong, please try again.",
      status: error.response?.status,
      code: error.code,
    };
  }

  return { message: "An unexpected error occurred." };
}
```

## Rules Of Thumb

- Components and hooks do not import Axios directly.
- Components do not contain inline endpoint URL strings.
- Feature API files own endpoint paths.
- API functions have explicit input and return types.
- Auth and 401 handling live in interceptors.
- Error UI uses the normalized error shape.
