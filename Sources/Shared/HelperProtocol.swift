import Foundation

public enum HelperMachService {
    public static let name = "com.gongahkia.sagasu.helper"
}

@objc public protocol SagasuHelperXPCProtocol {
    func currentSnapshot(reply: @escaping (Data?, NSError?) -> Void)
    func refresh(_ request: Data, reply: @escaping (Data?, NSError?) -> Void)
    func authState(reply: @escaping (Data?, NSError?) -> Void)
}
