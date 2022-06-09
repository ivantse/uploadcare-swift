//
//  File.swift
//  
//
//  Created by Sergei Armodin on 25.09.2021.
//

#if !os(watchOS)
import XCTest
@testable import Uploadcare

final class UploadAPIIntegrationTests: XCTestCase {
//	let uploadcare = Uploadcare(withPublicKey: "demopublickey", secretKey: "demopublickey")
	let uploadcare = Uploadcare(withPublicKey: String(cString: getenv("UPLOADCARE_PUBLIC_KEY")), secretKey: String(cString: getenv("UPLOADCARE_SECRET_KEY")))
	var newGroup: UploadedFilesGroup?

	func test01_UploadFileFromURL_and_UploadStatus() {
		let expectation = XCTestExpectation(description: "test01_UploadFileFromURL_and_UploadStatus")

		// upload from url
		let url = URL(string: "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png?\(UUID().uuidString)")!
		let task = UploadFromURLTask(sourceUrl: url)
			.checkURLDuplicates(true)
			.saveURLDuplicates(true)
			.filename("file_from_url")
			.store(.doNotStore)

		uploadcare.uploadAPI.upload(task: task) { [unowned self] result, error in
			if let error = error {
				XCTFail(error.detail)
				expectation.fulfill()
				return
			}

			XCTAssertNotNil(result)

			guard let token = result?.token else {
				XCTFail("no token")
				expectation.fulfill()
				return
			}

			delay(1.0) { [unowned self] in
				self.uploadcare.uploadAPI.uploadStatus(forToken: token) { status, error in
					defer { expectation.fulfill() }

					if let error = error {
						XCTFail(error.detail)
					}

					XCTAssertNotNil(status)
				}
			}

		}

		wait(for: [expectation], timeout: 10.0)
	}

	func test02_DirectUpload() {
		let expectation = XCTestExpectation(description: "test02_DirectUpload")

		let url = URL(string: "https://source.unsplash.com/random")!
		let data = try! Data(contentsOf: url)

		DLog("size of file: \(sizeString(ofData: data))")

		uploadcare.uploadAPI.directUpload(files: ["random_file_name.jpg": data], store: .doNotStore, { progress in
			DLog("upload progress: \(progress * 100)%")
		}) { resultDictionary, error in
			defer { expectation.fulfill() }

			if let error = error {
				XCTFail(error.detail)
				return
			}

			XCTAssertNotNil(resultDictionary)
			XCTAssertFalse(resultDictionary!.isEmpty)

			for file in resultDictionary! {
				DLog("uploaded file name: \(file.key) | file id: \(file.value)")
			}
		}

		wait(for: [expectation], timeout: 20.0)
	}

	func test03_DirectUploadInForeground() {
		let expectation = XCTestExpectation(description: "test03_DirectUploadInForeground")

		let url = URL(string: "https://source.unsplash.com/random")!
		let data = try! Data(contentsOf: url)

		DLog("size of file: \(sizeString(ofData: data))")


		uploadcare.uploadAPI.directUploadInForeground(files: ["random_file_name.jpg": data], store: .doNotStore, { (progress) in
			DLog("upload progress: \(progress * 100)%")
		}) { (resultDictionary, error) in
			defer { expectation.fulfill() }

			if let error = error {
				XCTFail(error.detail)
				return
			}

			XCTAssertNotNil(resultDictionary)
			XCTAssertFalse(resultDictionary!.isEmpty)

//			for file in resultDictionary! {
//				DLog("uploaded file name: \(file.key) | file id: \(file.value)")
//			}
		}

		wait(for: [expectation], timeout: 10.0)
	}

	func test04_DirectUploadInForegroundCancel() {
		let expectation = XCTestExpectation(description: "test04_DirectUploadInForegroundCancel")

		let url = URL(string: "https://source.unsplash.com/random")!
		let data = try! Data(contentsOf: url)

		DLog("size of file: \(sizeString(ofData: data))")

		let task = uploadcare.uploadAPI.directUploadInForeground(files: ["random_file_name.jpg": data], store: .doNotStore, { (progress) in
			DLog("upload progress: \(progress * 100)%")
		}) { (resultDictionary, error) in
			defer { expectation.fulfill() }

			XCTAssertNotNil(error)
			XCTAssertNil(resultDictionary)
		}

		task.cancel()

		wait(for: [expectation], timeout: 10.0)
	}

	func test05_UploadFileInfo() {
		let expectation = XCTestExpectation(description: "test05_UploadFileInfo")

		let url = URL(string: "https://source.unsplash.com/random?\(UUID().uuidString)")!
		let data = try! Data(contentsOf: url)

		DLog("size of file: \(sizeString(ofData: data))")

		uploadcare.uploadAPI.directUploadInForeground(files: ["random_file_name.jpg": data], store: .doNotStore, { (progress) in
			DLog("upload progress: \(progress * 100)%")
		}) { (resultDictionary, error) in
			if let error = error {
				XCTFail(error.detail)
				expectation.fulfill()
				return
			}

			XCTAssertNotNil(resultDictionary)
			XCTAssertFalse(resultDictionary!.isEmpty)

			let fileId = resultDictionary!.first!.value
			self.uploadcare.uploadAPI.fileInfo(withFileId: fileId) { (info, error) in
				defer { expectation.fulfill() }

				if let error = error {
					XCTFail(error.detail)
					return
				}

				XCTAssertNotNil(info)
			}
		}

		wait(for: [expectation], timeout: 10.0)
	}

	func test06_MainUpload_Cancel() {
		let url = URL(string: "https://source.unsplash.com/random")!
		let data = try! Data(contentsOf: url)

		let expectation = XCTestExpectation(description: "test06_MainUpload_Cancel")
		let task = uploadcare.uploadFile(data, withName: "random_file_name.jpg", store: .doNotStore) { progress in
			DLog("upload progress: \(progress * 100)%")
		} _: { file, error in
			defer { expectation.fulfill() }

			XCTAssertNotNil(error)
			XCTAssertEqual(error?.detail, "cancelled")
		}

		task.cancel()

		wait(for: [expectation], timeout: 10.0)
	}

	func test07_MainUpload_PauseResume() {
		let url = URL(string: "https://ucarecdn.com/26ba15c5-431b-4ecc-8be1-7a094ba3ba72/")!
		let fileForUploading = uploadcare.file(withContentsOf: url)!

		let expectation = XCTestExpectation(description: "test07_MainUpload_PauseResume")

		var task: UploadTaskable?
		var didPause = false
		let onProgress: (Double)->Void = { (progress) in
			DLog("progress: \(progress)")

			if !didPause {
				didPause.toggle()
				(task as? UploadTaskResumable)?.pause()

				delay(5.0) {
					(task as? UploadTaskResumable)?.resume()
				}
			}
		}

		task = fileForUploading.upload(withName: "Mona_Lisa_23mb.jpg", store: .doNotStore, onProgress, { file, error in
			defer { expectation.fulfill() }

			if let error = error {
				XCTFail(error.detail)
				return
			}

			XCTAssertNotNil(file)
		})

		// pause
		(task as? UploadTaskResumable)?.pause()
		delay(2.0) {
			(task as? UploadTaskResumable)?.resume()
		}

		wait(for: [expectation], timeout: 120.0)
	}

	func test08_fileInfo() {
		let expectation = XCTestExpectation(description: "test08_fileInfo")

		let url = URL(string: "https://source.unsplash.com/random")!
		let data = try! Data(contentsOf: url)

		uploadcare.uploadAPI.directUploadInForeground(files: ["random_file_name.jpg": data], store: .doNotStore, { (progress) in
			DLog("upload progress: \(progress * 100)%")
		}) { (resultDictionary, error) in
			if let error = error {
				XCTFail(error.detail)
				expectation.fulfill()
				return
			}

			XCTAssertNotNil(resultDictionary)

			let fileID = resultDictionary!.first!.value

			self.uploadcare.uploadAPI.fileInfo(withFileId: fileID) { file, error in
				defer { expectation.fulfill() }

				if let error = error {
					XCTFail(error.detail)
					return
				}

				XCTAssertNotNil(file)
			}
		}

		wait(for: [expectation], timeout: 10.0)
	}

	func test09_multipartUpload() {
		let url = URL(string: "https://ucarecdn.com/26ba15c5-431b-4ecc-8be1-7a094ba3ba72/")!
		let data = try! Data(contentsOf: url)

		let expectation = XCTestExpectation(description: "test09_multipartUpload")

		let onProgress: (Double)->Void = { (progress) in
			DLog("progress: \(progress)")
		}

		uploadcare.uploadAPI.multipartUpload(data, withName: "Mona_Lisa_23mb.jpg", store: .doNotStore, onProgress) { file, error in
			defer { expectation.fulfill() }

			if let error = error {
				XCTFail(error.detail)
				return
			}

			XCTAssertNotNil(file)
		}
		wait(for: [expectation], timeout: 120.0)
	}

	func test10_createFilesGroup_and_filesGroupInfo() {
		let expectation = XCTestExpectation(description: "test10_createFilesGroup_and_filesGroupInfo")

		let url = URL(string: "https://source.unsplash.com/random?\(UUID().uuidString)")!
		let data = try! Data(contentsOf: url)

		DLog("size of file: \(sizeString(ofData: data))")

		// upload a file
		uploadcare.uploadAPI.directUploadInForeground(files: ["random_file_name.jpg": data], store: .doNotStore, { progress in
			DLog("upload progress: \(progress * 100)%")
		}) { resultDictionary, error in
			if let error = error {
				XCTFail(error.detail)
				expectation.fulfill()
				return
			}

			XCTAssertNotNil(resultDictionary)
			XCTAssertFalse(resultDictionary!.isEmpty)

			// file info
			let fileId = resultDictionary!.first!.value
			self.uploadcare.uploadAPI.fileInfo(withFileId: fileId) { info, error in
				if let error = error {
					XCTFail(error.detail)
					expectation.fulfill()
					return
				}

				XCTAssertNotNil(info)

				self.newGroup = self.uploadcare.group(ofFiles:[info!])
				self.newGroup!.create { response, error in
					if let error = error {
						XCTFail(error.detail)
						expectation.fulfill()
						return
					}

					XCTAssertNotNil(response)
					XCTAssertNotNil(response!.files)
					XCTAssertFalse(response!.files!.isEmpty)

					XCTAssertEqual(response!.filesCount, 1)

					self.uploadcare.uploadAPI.filesGroupInfo(groupId: response!.id) { group, error in
						defer { expectation.fulfill() }

						if let error = error {
							XCTFail(error.detail)
							return
						}

						XCTAssertNotNil(group)
						XCTAssertNotNil(group!.files)
						XCTAssertFalse(group!.files!.isEmpty)
					}
				}
			}
		}

		wait(for: [expectation], timeout: 120.0)
	}
}

#endif
