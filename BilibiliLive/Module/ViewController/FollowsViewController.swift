//
//  FollowsViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import Alamofire
import SwiftyJSON
import UIKit

class FollowsViewController: StandardVideoCollectionViewController<DynamicFeedData> {
    var lastOffset = ""

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 1
    }

    override func request(page: Int) async throws -> [DynamicFeedData] {
        if page == 1 {
            lastOffset = ""
        }
        let info = try await WebRequest.requestFollowsFeed(offset: lastOffset, page: page)
        lastOffset = info.offset
        Logger.debug("request page\(page) get count:\(info.videoFeeds.count) next offset:\(info.offset)")
        return info.videoFeeds
    }

    override func goDetail(with feed: DynamicFeedData) {
        let epid = feed.modules.module_dynamic.major?.pgc?.epid
        // 纯 PGC 动态（aid=0）走 epid 详情，避免用 aid=0 请求详情页拿不到内容。
        if feed.aid == 0, let epid, epid > 0 {
            let detailVC = VideoDetailViewController.create(epid: epid)
            detailVC.present(from: self)
            return
        }
        let detailVC = VideoDetailViewController.create(aid: feed.aid, cid: feed.cid, epid: epid)
        detailVC.present(from: self)
    }
}

extension WebRequest {
    struct DynamicFeedInfo: Codable {
        let items: [DynamicFeedData]
        let offset: String
        let update_num: Int
        let update_baseline: String
        let has_more: Bool
        var videoFeeds: [DynamicFeedData] {
            // 只保留可跳转的：普通视频(aid>0) 或有有效 epid 的番剧动态。
            // epid 变可选后，pgc!=nil 但 epid=nil 的动态点了会用 aid=0 请求详情，直接过滤掉。
            return items
                .filter({ $0.aid != 0 || ($0.modules.module_dynamic.major?.pgc?.epid ?? 0) > 0 })
        }

        enum CodingKeys: String, CodingKey {
            case items, offset, update_num, update_baseline, has_more
        }

        // 关注动态流是异构数据，单条脏数据（epid/字段类型不符、缺字段）不应让整页
        // 解码失败导致关注 tab 报错。逐条容错跳过坏项，顶层字段全部柔性解码。
        private struct LossyItem: Decodable {
            let value: DynamicFeedData?
            init(from decoder: Decoder) throws {
                value = try? DynamicFeedData(from: decoder)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let lossy = (try? container.decode([LossyItem].self, forKey: .items)) ?? []
            let decoded = lossy.compactMap { $0.value }
            let raw = lossy.count
            if decoded.count < raw {
                Logger.warn("[Follows] skipped \(raw - decoded.count)/\(raw) undecodable dynamic items")
            }
            items = decoded
            if let s = try? container.decodeIfPresent(String.self, forKey: .offset) {
                offset = s
            } else if let i = try? container.decodeIfPresent(Int.self, forKey: .offset) {
                offset = String(i)
            } else {
                offset = ""
            }
            if let i = try? container.decodeIfPresent(Int.self, forKey: .update_num) {
                update_num = i
            } else if let s = try? container.decodeIfPresent(String.self, forKey: .update_num) {
                update_num = Int(s) ?? 0
            } else {
                update_num = 0
            }
            update_baseline = (try? container.decodeIfPresent(String.self, forKey: .update_baseline)) ?? ""
            has_more = (try? container.decodeIfPresent(Bool.self, forKey: .has_more)) ?? false
        }
    }

    static func requestFollowsFeed(offset: String, page: Int) async throws -> DynamicFeedInfo {
        var param: [String: Any] = ["type": "all", "timezone_offset": "-480", "page": page]
        // offset 是服务端返回的分页 token，可能是非纯数字字符串；非空即原样回传，
        // 避免只接受数字 offset 时翻页失效或反复请求第一页。
        if !offset.isEmpty {
            param["offset"] = offset
        }
        let res: DynamicFeedInfo = try await request(url: "https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all", parameters: param)
        // 本页全被过滤但还有更多时继续翻，但必须保证 offset 前进（非空且与上次不同），
        // 否则异常 offset("" 或不变) 会无限重复请求同一页。
        if res.videoFeeds.isEmpty, res.has_more, !res.offset.isEmpty, res.offset != offset {
            return try await requestFollowsFeed(offset: res.offset, page: page)
        }
        return res
    }
}

struct DynamicFeedData: Codable, PlayableData, DisplayData {
    var aid: Int {
        if let str = modules.module_dynamic.major?.archive?.aid {
            return Int(str) ?? 0
        }
        return 0
    }

    var cid: Int { return 0 }

    var title: String {
        return modules.module_dynamic.major?.archive?.title ?? modules.module_dynamic.major?.pgc?.title ?? ""
    }

    var ownerName: String {
        return modules.module_author.name
    }

    var pic: URL? {
        return URL(string: modules.module_dynamic.major?.archive?.cover ?? "") ?? modules.module_dynamic.major?.pgc?.cover
    }

    var avatar: URL? {
        return URL(string: modules.module_author.face)
    }

    var date: String? {
        return modules.module_author.pub_time
    }

    var overlay: DisplayOverlay? {
        var leftItems = [DisplayOverlay.DisplayOverlayItem]()
        var rightItems = [DisplayOverlay.DisplayOverlayItem]()
        if let stat = modules.module_dynamic.major?.archive?.stat {
            if let play = stat.play {
                leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "play.rectangle", text: play == "0" ? "-" : "\(play)"))
            }
            if let danmaku = stat.danmaku {
                leftItems.append(DisplayOverlay.DisplayOverlayItem(icon: "list.bullet.rectangle", text: danmaku == "0" ? "-" : "\(danmaku)"))
            }
        }
        if let durationText = modules.module_dynamic.major?.archive?.duration_text {
            rightItems.append(DisplayOverlay.DisplayOverlayItem(icon: nil, text: durationText))
        }
        return DisplayOverlay(leftItems: leftItems, rightItems: rightItems)
    }

    let type: String
    let basic: Basic
    let modules: Modules
    let id_str: String

    struct Basic: Codable, Hashable {
        let comment_id_str: String
        let comment_type: Int
    }

    struct Modules: Codable, Hashable {
        let module_author: ModuleAuthor
        let module_dynamic: ModuleDynamic

        struct ModuleAuthor: Codable, Hashable {
            let face: String
            let mid: Int
            let name: String
            let pub_time: String
        }

        struct ModuleDynamic: Codable, Hashable {
            let major: Major?

            struct Major: Codable, Hashable {
                let archive: Archive?
                let pgc: Pgc?

                struct Archive: Codable, Hashable {
                    let aid: String?
                    let cover: String?
                    let desc: String?
                    let title: String?
                    let duration_text: String?
                    let stat: Stat?

                    struct Stat: Codable, Hashable {
                        let danmaku: String?
                        let play: String?
                    }
                }

                struct Pgc: Codable, Hashable {
                    let epid: Int?
                    let title: String?
                    let cover: URL?
                    let jump_url: URL?

                    enum CodingKeys: String, CodingKey {
                        case epid, title, cover, jump_url
                    }

                    // B站 API 有时把 epid 返回成 String 或缺失，非可选 Int 会让整条
                    // 动态（乃至整页）解码失败。容忍 Int/String/null/missing。
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .epid) {
                            epid = intVal
                        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .epid) {
                            epid = Int(strVal)
                        } else {
                            epid = nil
                        }
                        title = try container.decodeIfPresent(String.self, forKey: .title)
                        cover = try container.decodeIfPresent(URL.self, forKey: .cover)
                        jump_url = try container.decodeIfPresent(URL.self, forKey: .jump_url)
                    }
                }
            }
        }
    }
}
