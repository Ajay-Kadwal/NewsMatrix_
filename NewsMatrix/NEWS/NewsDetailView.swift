//
//  NewsDetailView.swift
//  NewsMatrix
//
//  Created by AJAY KADWAL on 17/11/25.
//

import SwiftUI
import Combine
import SafariServices

// A wrapper that allows using SFSafariViewController inside SwiftUI
struct SafariView: UIViewControllerRepresentable {
    
    let url: URL // The webpage URL to open
    
    // Creates the Safari view controller
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    // No runtime updates needed
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}

struct NewsArticle: Codable, Identifiable {
    var id = UUID()
    let title: String?
    let description: String?
    let url: String?
    let urlToImage: String?
    
    enum CodingKeys: String,CodingKey {
        case title
        case description
        case url
        case urlToImage
    }
}

class NewsResponse: Codable {
    let news: [NewsArticle]
}

class NewsApiService {
    
    func fetchLatestNews() -> AnyPublisher<[NewsArticle], Error> {
        let url = URL(string: "https://news.knowivate.com/api/latest")!
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: NewsResponse.self, decoder: JSONDecoder())
            .map { $0.news }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

class NewsViewModel: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    let service = NewsApiService()
    var cancellables = Set<AnyCancellable>()
    
    func loadNews() {
        // Start loader and clear errors
        isLoading = true
        errorMessage = ""
        
        // Give SwiftUI a chance to show loader before fast API completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            
            guard let self = self else { return }
            
            self.service.fetchLatestNews()
                .sink { completion in
                    
                    self.isLoading = false   // Hide loading indicator
                    
                    if case .failure = completion {
                        self.errorMessage = "Unable to load news. Please try again."
                    }
                    
                } receiveValue: { articles in
                    self.articles = articles
                }
                .store(in: &self.cancellables)
        }
    }
    
    func retryNews() {
        loadNews()
    }
}

struct NewsDetailView: View {
    
    @StateObject var vm = NewsViewModel()
    var body: some View {
        NavigationStack {
            List {
                if vm.isLoading {
                    ProgressView("Loading Letest news...")
                        .padding()
                }
                if !vm.errorMessage.isEmpty {
                    VStack(spacing: 12) {
                        
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            vm.retryNews() // Calls retry()
                        }) {
                            Text("Retry")
                                .fontWeight(.bold)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                
                ForEach(vm.articles) { article in
                    NavigationLink(destination: NewsDetailViews(article: article)) {
                        
                        VStack (alignment: .leading, spacing: 8){
                            Text(article.title ?? "NO title..")
                                .font(.headline)
                            
                            Text(article.description ?? "NO description..")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            // 🔥 Pull-to-refresh logic
            .refreshable {
                vm.loadNews()// Simply trigger API again
            }
            .listStyle(.plain)
            .navigationTitle("Latest News")
            .onAppear { vm.loadNews() }
        }
    }
}

struct NewsDetailViews: View {
    let article: NewsArticle
    @State private var showSafari = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 16) {
                // --- IMAGE ---
                if let imgUrl = article.urlToImage,
                   let url = URL(string: imgUrl) {
                    
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                        case .failure:
                            Color.gray.opacity(0.2)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(10)
                }
                
                // --- TITLE ---
                Text(article.title ?? "NO title")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // --- DESCRIPTION ---
                Text(article.description ?? "NO description")
                    .font(.body)
                    .foregroundStyle(.gray)
                
                // --- BUTTON ---
                if let link = article.url,
                   let _ = URL(string: link) {
                    Button("Read Full Article") {
                        showSafari = true
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 5)
        }
        .sheet(isPresented: $showSafari) {
            if let link = article.url,
               let url = URL(string: link) {
                SafariView(url: url)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
// "https://news.knowivate.com/api/latest"
#Preview {
    NewsDetailView()
}
