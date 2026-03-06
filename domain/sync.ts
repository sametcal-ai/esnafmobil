export type SyncDirection = 'PUSH' | 'PULL' | 'BIDIRECTIONAL';

export interface SyncMetadata {
  id: string;
  updatedAt: string; // ISO string
  deleted?: boolean;
}

/**
 * Minimal shape that any syncable entity must implement.
 */
export interface SyncableEntity extends SyncMetadata {
  [key: string]: unknown;
}

export interface LocalDataSource<T extends SyncableEntity> {
  listUnsynced(): Promise<T[]>;
  applyRemoteChanges(changes: T[]): Promise<void>;
  markAsSynced(ids: string[]): Promise<void>;
}

export interface RemoteDataSource<T extends SyncableEntity> {
  pushChanges(changes: T[]): Promise<void>;
  pullChanges(since?: string): Promise<T[]>;
}

/**
 * Simple conflict resolution strategy:
 * - Last write wins based on updatedAt timestamp.
 * - Deletes take precedence over updates when timestamps are equal.
 */
export function resolveConflict(local: SyncableEntity, remote: SyncableEntity): SyncableEntity {
  const localTime = new Date(local.updatedAt).getTime();
  const remoteTime = new Date(remote.updatedAt).getTime();

  if (remoteTime > localTime) {
    return remote;
  }

  if (remoteTime < localTime) {
    return local;
  }

  // Same timestamp: prefer delete if any side is marked deleted.
  if (local.deleted || remote.deleted) {
    return {
      ...(localTime >= remoteTime ? local : remote),
      deleted: true,
    };
  }

  // Same timestamp, no delete flag – keep remote for determinism.
  return remote;
}

/**
 * SyncEngine ensures consistency between local and remote sources.
 *
 * It:
 * - pushes local unsynced changes
 * - pulls remote changes
 * - applies conflict resolution
 */
export class SyncEngine<T extends SyncableEntity> {
  private readonly local: LocalDataSource<T>;
  private readonly remote: RemoteDataSource<T>;

  constructor(local: LocalDataSource<T>, remote: RemoteDataSource<T>) {
    this.local = local;
    this.remote = remote;
  }

  async sync(): Promise<void> {
    // 1. Push all local unsynced changes first.
    const unsynced = await this.local.listUnsynced();
    if (unsynced.length > 0) {
      await this.remote.pushChanges(unsynced);
    }

    // 2. Pull remote changes.
    const remoteChanges = await this.remote.pullChanges();

    // 3. Apply remote changes locally, resolving conflicts.
    // The LocalDataSource implementation is responsible for
    // calling resolveConflict when merging with its current state.
    await this.local.applyRemoteChanges(remoteChanges);

    // 4. Mark local changes as synced once both sides are consistent.
    if (unsynced.length > 0) {
      await this.local.markAsSynced(unsynced.map((e) => e.id));
    }
  }
}