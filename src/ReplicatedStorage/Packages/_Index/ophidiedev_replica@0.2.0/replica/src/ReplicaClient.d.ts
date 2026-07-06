/// <reference types="@rbxts/types" />

type ReplicaPath = Array<string | number>;
type ReplicaAction = "Set" | "SetValues" | "TableInsert" | "TableRemove";

interface Connection {
  Disconnect(): void;
}

interface WriteSignalMap {
  [functionName: string]: Map<Connection, true>;
}

interface ReplicaObject {
  readonly Tags: Record<string | number, unknown>;
  readonly Data: Record<string | number, unknown>;
  readonly Id: number;
  readonly Token: string;
  readonly Parent?: ReplicaObject;
  readonly Children: Map<ReplicaObject, true>;
  BoundInstance?: Instance;
  readonly OnClientEvent: RBXScriptSignal;

  OnSet(path: ReplicaPath, listener: (newValue: unknown, oldValue: unknown) => void): Connection;
  OnWrite(functionName: string, listener: (...args: Array<unknown>) => void): Connection;
  OnChange(
    listener: (action: ReplicaAction, path: ReplicaPath, param1: unknown, param2?: unknown) => void,
  ): Connection;
  GetChild(token: string): ReplicaObject | undefined;
  FireServer(...args: Array<unknown>): void;
  UFireServer(...args: Array<unknown>): void;
  Identify(): string;
  IsActive(): boolean;

  Set(path: ReplicaPath, value: unknown): void;
  SetValues(path: ReplicaPath, values: Record<string | number, unknown>): void;
  TableInsert(path: ReplicaPath, value: unknown, index?: number): number;
  TableRemove(path: ReplicaPath, index: number): unknown;
  Write<T extends Array<unknown>, R>(functionName: string, ...args: T): R;
}

interface ReplicaDebugState {
  readonly TokenReplicas: Record<string, Map<ReplicaObject, true>>;
  readonly Replicas: Record<number, ReplicaObject>;
  readonly BindReplicas: Record<number, ReplicaObject>;
  readonly BindInstances: Record<number, Instance | undefined>;
}

interface ReplicaNamespace {
  IsReady: boolean;
  OnLocalReady: RBXScriptSignal;

  readonly RequestData: () => void;
  readonly OnNew: (token: string, listener: (replica: ReplicaObject) => void) => Connection;
  readonly FromId: (id: number) => ReplicaObject | undefined;
  readonly Test: () => ReplicaDebugState;
}

declare const ReplicaClient: ReplicaNamespace;
export = ReplicaClient;
