//
//  ViewControllerPreview.swift
//  Taskly
//
//  Created by EfeBülbül on 8.12.2025.
//


import Foundation
import SwiftUI
struct ViewControllerPreview: UIViewControllerRepresentable {
    let viewControllerBuilder: () -> UIViewController
    init(_ viewControllerBuilder: @escaping () -> UIViewController) {
        self.viewControllerBuilder = viewControllerBuilder
    }
    func makeUIViewController(context: Context) -> some UIViewController {
        return self.viewControllerBuilder()
    }
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}