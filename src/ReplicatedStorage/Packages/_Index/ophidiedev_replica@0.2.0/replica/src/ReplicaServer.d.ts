/// <reference types="@rbxts/types" />

type ReplicaPath = string | number | Array<string | number>;

interface ReplicaToken {
    readonly _replicaTokenBrand: unique symbol;
}

interface ReplicaConstructorParams<
	TData,
    TTags
>{
    readonly Token?: string | ReplicaToken;
    readonly Tags?: Readonly<TTags>;
    readonly Data?: Readonly<TData>;
    readonly WriteLib?: Record<string, (...args: unknown[]) => void>;
}

interface ReplicaInstance<
    TData,
    TTags
> {
    readonly Tags: Readonly<TTags>;
    readonly Data: Readonly<TData>;
    readonly Id: number;
    readonly Token: string;
    readonly Parent?: ReplicaInstance<unknown,unknown> | undefined;
    readonly Children: ReadonlyMap<ReplicaInstance<unknown,unknown>, true>;
    readonly BoundInstance?: Instance;
    readonly OnServerEvent: RBXScriptSignal<(player: Player, ...args: unknown[]) => void>;
    readonly Maid: { Destroy(): void };

    Set(path: ReplicaPath, value: unknown): void;
    SetValues(path: ReplicaPath, values: Record<string, unknown>): void;
    TableInsert(path: ReplicaPath, value: unknown, index?: number): void;
    TableRemove(path: ReplicaPath, index: number): void;
    Write(functionName: string, ...args: unknown[]): void;
    FireClient(player: Player, ...args: unknown[]): void;
    FireAllClients(...args: unknown[]): void;
    UFireClient(player: Player, ...args: unknown[]): void;
    UFireAllClients(...args: unknown[]): void;
    SetParent(parent?: ReplicaInstance<unknown,unknown>): void;
    BindToInstance(instance: Instance): void;
    Replicate(): void;
    DontReplicate(): void;
    Subscribe(player: Player): void;
    Unsubscribe(player: Player): void;
    Identify(): string;
    IsActive(): boolean;
    Destroy(): void;
}

interface ReplicaStatic {
    // readonly ReadyPlayers: Readonly<Record<Player, true>>;
	readonly ReadyPlayers: ReadonlyMap<Player,true>
    readonly NewReadyPlayer: RBXScriptSignal<(player: Player) => void>;
    readonly RemovingReadyPlayer: RBXScriptSignal<(player: Player) => void>;

	new<TData,TTags = Record<string, unknown>>(params: ReplicaConstructorParams<TData,TTags>): ReplicaInstance<TData,TTags>;

    readonly Token: (tokenString: string) => ReplicaToken;
    readonly FromId: (id: number) => ReplicaInstance<unknown,unknown> | undefined;
}

declare const ReplicaServer: ReplicaStatic;
export = ReplicaServer;
