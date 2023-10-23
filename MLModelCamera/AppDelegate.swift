//
//  AppDelegate.swift
//  CoreMLPlayground
//
//  Created by Shuichi Tsutsumi on 2018/06/14.
//  Copyright © 2018 Shuichi Tsutsumi. All rights reserved.
//

import UIKit

@UIApplicationMain //main関数の実行プログラムの記述を省略している　Main関数ではAppDelegateクラスを呼び出す
class AppDelegate: UIResponder, UIApplicationDelegate {//delegate = Appleの設計図を使わせてくれと頼むこと(頼む代理人を選ぶこと)

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

//詳しくはhttps://qiita.com/Howasuto/items/b362991fafd8b190e260
