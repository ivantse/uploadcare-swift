import Foundation
import Alamofire


/// Upload API base url
let uploadAPIBaseUrl: String = "https://upload.uploadcare.com"

/// REST API base URL
let RESTAPIBaseUrl: String = "https://api.uploadcare.com"


public struct Uploadcare {
	
	public enum AuthScheme {
		case simple
		case signed
	}
	
	/// Public Key.  It is required when using Upload API.
	internal var publicKey: String
	
	/// Secret Key. Is used for authorization
	internal var secretKey: String
	
	/// Auth scheme
	internal var authScheme: AuthScheme = .simple
	
	/// Alamofire session manager
	private var manager = SessionManager()
	
	
	/// Initialization
	/// - Parameter publicKey: Public Key.  It is required when using Upload API.
	public init(withPublicKey publicKey: String, secretKey: String) {
		self.publicKey = publicKey
		self.secretKey = secretKey
	}
	
	
	/// Method for integration testing
	public static func sayHi() {
		print("Uploadcare says Hi!")
	}
}


private extension Uploadcare {
	func makeError(fromResponse response: DataResponse<Data>) -> Error {
		let status: Int = response.response?.statusCode ?? 0
		
		var message = ""
		if let data = response.data {
			message = String(data: data, encoding: .utf8) ?? ""
		}
		
		return Error(status: status, message: message)
	}
}


// MARK: - Upload API
extension Uploadcare {
	
	/// File info
	/// - Parameters:
	///   - fileId: File ID
	///   - completionHandler: completion handler
	public func fileInfo(
		withFileId fileId: String,
		_ completionHandler: @escaping (FileInfo?, Error?) -> Void
	) {
		let urlString = uploadAPIBaseUrl + "/info?pub_key=\(self.publicKey)&file_id=\(fileId)"
		guard let url = URL(string: urlString) else { return }
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = HTTPMethod.get.rawValue
		
		request(urlRequest)
			.validate(statusCode: 200..<300)
			.responseData { response in
				switch response.result {
				case .success(let data):
					let decodedData = try? JSONDecoder().decode(FileInfo.self, from: data)
		
					guard let fileInfo = decodedData else {
						completionHandler(nil, Error.defaultError())
						return
					}

					completionHandler(fileInfo, nil)
				case .failure(_):
					let error = self.makeError(fromResponse: response)
					completionHandler(nil, error)
				}
		}
	}
	
	/// Direct upload from url
	/// - Parameters:
	///   - task: upload settings
	///   - completionHandler: callback
	public func upload(
		task: UploadFromURLTask,
		_ completionHandler: @escaping (UploadFromURLResponse?, Error?) -> Void
	) {
		var urlString = uploadAPIBaseUrl + "/from_url?pub_key=\(self.publicKey)&source_url=\(task.sourceUrl.absoluteString)"
			
		urlString += "&store=\(task.store.rawValue)"
		
		if let filenameVal = task.filename {
			urlString += "&filename=\(filenameVal)"
		}
		if let checkURLDuplicatesVal = task.checkURLDuplicates {
			let val = checkURLDuplicatesVal == true ? "1" : "0"
			urlString += "&check_URL_duplicates=\(val)"
		}
		if let saveURLDuplicatesVal = task.saveURLDuplicates {
			let val = saveURLDuplicatesVal == true ? "1" : "0"
			urlString += "&save_URL_duplicates=\(val)"
		}
		if let signatureVal = task.signature {
			urlString += "&signature=\(signatureVal)"
		}
		if let expireVal = task.expire {
			urlString += "&expire=\(Int(expireVal))"
		}
		
		guard let url = URL(string: urlString) else { return }
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = HTTPMethod.post.rawValue
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		request(urlRequest)
			.validate(statusCode: 200..<300)
			.responseData { response in
				switch response.result {
				case .success(let data):
					let decodedData = try? JSONDecoder().decode(UploadFromURLResponse.self, from: data)

					guard let responseData = decodedData else {
						completionHandler(nil, Error.defaultError())
						return
					}

					completionHandler(responseData, nil)
					break
				case .failure(_):
					let error = self.makeError(fromResponse: response)
					completionHandler(nil, error)
				}
		}
	}
	
	/// Get status for file upload from URL
	/// - Parameters:
	///   - token: token recieved from upload method
	///   - completionHandler: callback
	public func uploadStatus(
		forToken token: String,
		_ completionHandler: @escaping (UploadFromURLStatus?, Error?) -> Void
	) {
		let urlString = uploadAPIBaseUrl + "/from_url/status/?token=\(token)"
		guard let url = URL(string: urlString) else { return }
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = HTTPMethod.get.rawValue
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		
		request(urlRequest)
			.validate(statusCode: 200..<300)
			.responseData { response in
				switch response.result {
				case .success(let data):
					let decodedData = try? JSONDecoder().decode(UploadFromURLStatus.self, from: data)

					guard let responseData = decodedData else {
						completionHandler(nil, Error.defaultError())
						return
					}

					completionHandler(responseData, nil)
					break
				case .failure(_):
					let error = self.makeError(fromResponse: response)
					completionHandler(nil, error)
				}
		}
	}
	
	public func upload(
		files: [String:Data],
		store: StoringBehavior? = nil,
		signature: String? = nil,
		expire: Int? = nil,
		_ completionHandler: @escaping ([String: String]?, Error?) -> Void
	) {
		let urlString = uploadAPIBaseUrl + "/base/"
		manager.upload(
			multipartFormData: { (multipartFormData) in
				if let publicKeyData = self.publicKey.data(using: .utf8) {
					multipartFormData.append(publicKeyData, withName: "UPLOADCARE_PUB_KEY")
				}
				
				for file in files {
					multipartFormData.append(file.value, withName: file.key, fileName: file.key, mimeType: mimeType(for: file.value))
				}
				
				if let storeVal = store, let data = storeVal.rawValue.data(using: .utf8) {
					multipartFormData.append(data, withName: "UPLOADCARE_STORE")
				}
				
				if let signatureVal = signature, let data = signatureVal.data(using: .utf8) {
					multipartFormData.append(data, withName: "signature")
				}
				if var expireVal = expire {
					let data = Data(bytes: &expireVal, count: MemoryLayout.size(ofValue: expireVal))
					multipartFormData.append(data, withName: "expire")
				}
		},
			to: urlString
		) { (result) in
			switch result {
			case .success(let upload, _, _):
				
//				upload.uploadProgress(closure: { (progress) in
//					DLog("Upload progress: \(progress.fractionCompleted)")
//				})
				
				upload.response { (response) in
					if response.response?.statusCode == 200, let data = response.data {
						let decodedData = try? JSONDecoder().decode([String:String].self, from: data)
						guard let resultData = decodedData else {
							completionHandler(nil, Error.defaultError())
							return
						}
						completionHandler(resultData, nil)
						return
					}
					
					// error happened
					let status: Int = response.response?.statusCode ?? 0
					var message = ""
					if let data = response.data {
						message = String(data: data, encoding: .utf8) ?? ""
					}
					let error = Error(status: status, message: message)
					completionHandler(nil, error)
				}

			case .failure(let encodingError):
				completionHandler(nil, Error(status: 0, message: encodingError.localizedDescription))
			}
		}
	}
}
