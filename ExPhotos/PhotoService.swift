//
//  PhotoService.swift
//  ExPhotos
//
//  Created by Jake.K on 2022/06/30.
//

import Photos
import RxSwift
import RxCocoa

/*
 Photos 프레임워크
 - PHAsset: 사진 라이브러리에 있는 이미지, 비디오와 같은 하나의 애셋을 의미
 - PHAssetCollection: PHAsset의 컬렉션
 - PHCachingImageManager: 요청한 크기에 맞게 이미지를 로드하여 캐싱까지 수행
 - PHFetchResult: 내부적으로 thread-safe하게 사진 라이브러리에 접근하여,
 */

enum MediaType {
  case all
  case image
  case video
}

final class PhotoService: NSObject {
  private enum Const {
    static let titleText: (MediaType?) -> String = { mediaType in
      switch mediaType {
      case .all:
        return "이미지와 동영상"
      case .image:
        return "이미지"
      case .video:
        return "동영상"
      default:
        return "비어있는 타이틀"
      }
    }
    static let predicate: (MediaType) -> NSPredicate = { mediaType in
      let format = "mediaType == %d"
      switch mediaType {
      case .all:
        return .init(
          format: format + " || " + format,
          PHAssetMediaType.image.rawValue,
          PHAssetMediaType.video.rawValue
        )
      case .image:
        return .init(
          format: format,
          PHAssetMediaType.image.rawValue
        )
      case .video:
        return .init(
          format: format,
          PHAssetMediaType.video.rawValue
        )
      }
    }
    static let sortDescriptors = [
      NSSortDescriptor(key: "createDate", ascending: false),
      NSSortDescriptor(key: "modificationDate", ascending: false)
    ]
  }
  
  private let imageManager = PHCachingImageManager()
  private var instance = PublishRelay<PHChange>()
  var didChangeInstance: Observable<PHChange> { self.instance.asObservable() }
  
  override init() {
    super.init()
    // PHPhotoLibraryChangeObserver 델리게이트
    // PHPhotoLibrary: 변경사항을 알려 데이터 리프레시에 사용
    PHPhotoLibrary.shared().register(self)
  }
  
  deinit {
    PHPhotoLibrary.shared().unregisterChangeObserver(self)
  }
  
  func requestImages(size: CGSize, contentMode: PHImageContentMode, scale: CGFloat) -> Observable<[PHAsset]> {
    self.getAlbumObservable(mediaType: .image)
      .map { asset -> [PHAsset] in
        let option = PHImageRequestOptions()
        option.isNetworkAccessAllowed = true // for icloud
        self.imageManager.requestImage(
          for: asset,
          targetSize: CGSize(width: size.width * scale, height: size.height * scale),
          contentMode: contentMode,
          options: option) { image, info in
            if let image = image {
              return image
            }
          }
      }
  }
  
  private func getAlbumObservable(mediaType: MediaType) -> Observable<[PHFetchResult<PHAsset>]> {
    Observable<[PHFetchResult<PHAsset>]>
      .create { observer -> Disposable in
        var albums = [PHFetchResult<PHAsset>]()
        defer {
          observer.onNext(albums)
          observer.onCompleted()
        }
        // PHFetchOptions: predicate를 이용하여 sorting, mediaType 등을 쿼리하는데 사용
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = Const.predicate(mediaType)
        let allAlbum = PHAsset.fetchAssets(with: fetchOptions)
        albums.append(allAlbum)
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
          with: .smartAlbum,
          subtype: .any,
          options: PHFetchOptions()
        )
        guard 0 < smartAlbums.count else { return Disposables.create() }
        smartAlbums.enumerateObjects { album, index, pointer in
          guard index + 1 < smartAlbums.count else {
            pointer.pointee = true
            return
          }
          if album.estimatedAssetCount == NSNotFound {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = Const.predicate(mediaType)
            fetchOptions.sortDescriptors = Const.sortDescriptors
            let smartAlbums = PHAsset.fetchAssets(in: album, options: fetchOptions)
            albums.append(smartAlbums)
          }
        }
        return Disposables.create()
      }
  }
}

extension PhotoService: PHPhotoLibraryChangeObserver {
  func photoLibraryDidChange(_ changeInstance: PHChange) {
    self.instance.accept(changeInstance)
  }
}
