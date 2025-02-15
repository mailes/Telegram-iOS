import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramBaseController
import AccountContext
import ChatListUI
import ListMessageItem
import AnimationCache
import MultiAnimationRenderer

public final class HashtagSearchController: TelegramBaseController {
    public enum Mode: Equatable {
        case generic
        case noChat
        case chatOnly
    }
    
    private let queue = Queue()
    
    private let context: AccountContext
    private let peer: EnginePeer?
    private let query: String
    let mode: Mode
    let publicPosts: Bool
    let stories: Bool
    let forceDark: Bool
    
    private var transitionDisposable: Disposable?
    private let openMessageFromSearchDisposable = MetaDisposable()
    
    private(set) var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private var controllerNode: HashtagSearchControllerNode {
        return self.displayNode as! HashtagSearchControllerNode
    }
    
    public init(context: AccountContext, peer: EnginePeer?, query: String, mode: Mode = .generic, publicPosts: Bool = false, stories: Bool = false, forceDark: Bool = false) {
        self.context = context
        self.peer = peer
        self.query = query
        self.mode = mode
        self.publicPosts = publicPosts
        self.stories = stories
        self.forceDark = forceDark
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        var presentationData = context.sharedContext.currentPresentationData.with { $0 }
        if forceDark {
            presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
        }
        self.presentationData = presentationData
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        var title = query
        if case .chatOnly = mode, let addressName = peer?.addressName {
            title = "\(query)@\(addressName)"
        }
        
        self.title = title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
                        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let self {
                let previousTheme = self.presentationData.theme
                let previousStrings = self.presentationData.strings
                
                var presentationData = presentationData
                if forceDark {
                    presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                }
                
                self.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
                    
                    self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
                    self.controllerNode.updatePresentationData(self.presentationData)
                }
            }
        })
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = HashtagSearchControllerNode(context: self.context, controller: self, peer: self.peer, query: self.query, navigationBar: self.navigationBar, navigationController: self.navigationController as? NavigationController)
        if let chatController = self.controllerNode.currentController {
            chatController.parentController = self
        }
        
        self.displayNodeDidLoad()
    }
        
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let _ = self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, transition: transition)
    }
}
