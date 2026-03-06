export type UserRole = 'ADMIN' | 'CASHIER';

export interface User {
  id: string;
  name: string;
  role: UserRole;
}

/**
 * Simple authorization helper for domain-level checks.
 */
export function canManageCatalog(user: User | null): boolean {
  return user?.role === 'ADMIN';
}

export function canAccessManagementScreen(user: User | null): boolean {
  return user?.role === 'ADMIN';
}