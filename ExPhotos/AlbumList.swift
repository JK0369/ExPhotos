//
//  AlbumList.swift
//  ExPhotos
//
//  Created by Jake.K on 2022/06/30.
//

import Photos

struct AlbumList {
  let name: String
  let count: Int
  let localID: String?
  let assetResults: PHFetchResult<PHAsset>?
}

extension AlbumList: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.localID == rhs.localID
  }
}
