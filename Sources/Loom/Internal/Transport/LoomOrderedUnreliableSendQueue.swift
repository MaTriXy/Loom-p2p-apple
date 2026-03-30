//
//  LoomOrderedUnreliableSendQueue.swift
//  Loom
//
//  Created by Ethan Lipnik on 3/30/26.
//

import Dispatch
import Foundation
import Network

package final class LoomOrderedUnreliableSendQueue: @unchecked Sendable {
    private let queue: DispatchQueue
    private let sendOperation: @Sendable (Data, @escaping @Sendable (NWError?) -> Void) -> Void
    private let stateLock = NSLock()
    private var isClosed = false

    package init(connection: NWConnection, queue: DispatchQueue) {
        self.queue = queue
        sendOperation = { [connection] data, onComplete in
            connection.send(content: data, completion: .contentProcessed { error in
                onComplete(error)
            })
        }
    }

    package init(
        queue: DispatchQueue,
        sendOperation: @escaping @Sendable (Data, @escaping @Sendable (NWError?) -> Void) -> Void
    ) {
        self.queue = queue
        self.sendOperation = sendOperation
    }

    package func enqueue(_ data: Data, onComplete: @escaping @Sendable (NWError?) -> Void) {
        queue.async { [self, sendOperation] in
            stateLock.lock()
            let isClosed = self.isClosed
            stateLock.unlock()
            guard !isClosed else {
                onComplete(.posix(.ECANCELED))
                return
            }

            sendOperation(data, onComplete)
        }
    }

    package func close() {
        stateLock.lock()
        isClosed = true
        stateLock.unlock()
    }
}
