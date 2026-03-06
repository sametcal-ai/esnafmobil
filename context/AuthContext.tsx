import React, { createContext, useContext, useMemo, useState } from 'react';

import type { User, UserRole } from '@/domain/auth';

interface AuthContextValue {
  user: User | null;
  loginAs(role: UserRole): void;
  logout(): void;
  hasRole(role: UserRole): boolean;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export const AuthProvider: React.FC<React.PropsWithChildren> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);

  const loginAs = (role: UserRole) => {
    setUser({
      id: role === 'ADMIN' ? 'admin-1' : 'cashier-1',
      name: role === 'ADMIN' ? 'Admin' : 'Cashier',
      role,
    });
  };

  const logout = () => setUser(null);

  const value = useMemo(
    () => ({
      user,
      loginAs,
      logout,
      hasRole: (role: UserRole) => user?.role === role,
    }),
    [user]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return ctx;
}