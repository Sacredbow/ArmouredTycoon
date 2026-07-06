import replicaServer from "./ReplicaServer";
import replicaClient from "./ReplicaClient";

type ReplicaServer = typeof replicaServer;
type ReplicaClient = typeof replicaClient;

/**
 * Resolved by the Luau module: ReplicaServer on the server, ReplicaClient on the client.
 * 
 * ```ts
 * // Example TS Code
 * 
 * // client
 * import Replica, {ReplicaClient as replicaClient} from "@rbxts/loleris-replica"
 * 
 * const ReplicaClient = Replica as replicaClient
 * 
 * ReplicaClient.RequestData()
 * 
 * // server
 * import Replica, {ReplicaServer as replicaServer} from "@rbxts/loleris-replica"
 * 
 * const ReplicaServer = Replica as replicaServer
 * 
 * interface dataType {
 *		Score: number
 *		Nested: {
 *			Value: boolean
 *		}
 *	}
 * 
 * const replica = new ReplicaServer<dataType>({
 *		Token: ReplicaServer.Token("GlobalData"),
 *		Data: {
 *			Score: 300,
 *			Nested: {
 *				Value: false
 *			}
 *		}
 *	})
 * 
 * ReplicaServer.Replicate()
 * ```
 */
declare const Replica: ReplicaServer | ReplicaClient;

export {ReplicaServer, ReplicaClient}
export default Replica;