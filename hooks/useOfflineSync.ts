import AsyncStorage from '@react-native-async-storage/async-storage';
import { useNetworkState } from 'expo-network';
import { useEffect, useState } from 'react';

import type { SyncableEntity } from '@/domain/sync';
import { SyncEngine } from '@/domain/sync';

interface UseOfflineSyncOptions<T extends SyncableEntity> {
  localDataSource: {
    listUnsynced(): Promise<T[]>;
    applyRemoteChanges(changes: T[]): Promise<void>;
    markAsSynced(ids: string[]): Promise<void>;
  };
  remoteDataSource: {
    pushChanges(changes: T[]): Promise<void>;
    pullChanges(since?: string): Promise<T[]>;
  };
  storageKey: string;
}

/**
 * Generic hook that:
 * - detects connectivity
 * - runs sync when connection is restored
 * - exposes basic offline state to the UI
 */
export function useOfflineSync<T extends SyncableEntity>(
  options: UseOfflineSyncOptions<T>
): { isOnline: boolean | null; isSyncing: boolean; lastSyncAt: string | null } {
  const { localDataSource, remoteDataSource, storageKey } = options;
  const networkState = useNetworkState();
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastSyncAt, setLastSyncAt] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const engine = new SyncEngine(localDataSource, remoteDataSource);

    async function maybeSync() {
      if (!networkState.isInternetReachable) {
        return;
      }

      setIsSyncing(true);
      try {
        await engine.sync();
        const now = new Date().toISOString();
        if (!cancelled) {
          setLastSyncAt(now);
          await AsyncStorage.setItem(`${storageKey}:lastSyncAt`, now);
        }
      } finally {
        if (!cancelled) {
          setIsSyncing(false);
        }
      }
    }

    // Run once when we come online.
    if (networkState.isInternetReachable) {
      void maybeSync();
    }

    return () => {
      cancelled = true;
    };
  }, [networkState.isInternetReachable, localDataSource, remoteDataSource, storageKey]);

  useEffect(() => {
    // Load last sync timestamp from storage on mount.
    AsyncStorage.getItem(`${storageKey}:lastSyncAt`).then((value) => {
      if (value) {
        setLastSyncAt(value);
      }
    });
  }, [storageKey]);

  return {
    isOnline: networkState.isInternetReachable ?? networkState.isConnected ?? null,
    isSyncing,
    lastSyncAt,
  };
}