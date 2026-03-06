import React from 'react';
import { View, Text, Button } from 'react-native';

import { useAuth } from '@/context/AuthContext';

export default function ManagementScreen() {
  const { user, hasRole, loginAs } = useAuth();
  const isAdmin = hasRole('ADMIN');

  if (!isAdmin) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 16 }}>
        <Text style={{ fontSize: 18, fontWeight: '600', marginBottom: 12 }}>
          Access restricted
        </Text>
        <Text style={{ textAlign: 'center', marginBottom: 16 }}>
          Only administrators can manage products, prices, and suppliers.
        </Text>
        {!user && (
          <Button title="Log in as Admin (demo)" onPress={() => loginAs('ADMIN')} />
        )}
      </View>
    );
  }

  return (
    <View style={{ flex: 1, padding: 16, gap: 12 }}>
      <Text style={{ fontSize: 22, fontWeight: '700', marginBottom: 8 }}>
        Management
      </Text>
      <Text style={{ marginBottom: 16 }}>
        Here you can manage products, prices, and suppliers. This screen is restricted to admin users.
      </Text>
      {/* TODO: Replace this placeholder content with actual management UI. */}
    </View>
  );
}