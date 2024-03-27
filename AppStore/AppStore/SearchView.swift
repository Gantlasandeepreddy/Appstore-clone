//
//  ContentView.swift
//  AppStore
//
//  Created by sandeep on 12/24/23.
//

import SwiftUI
import Combine

extension Int {
    var roundedWithAbbreviations: String {
        let number = Double(self)
        let thousand = number / 1000
        let million = number / 1000000
        if million >= 1.0 {
            return "\(round(million*10)/10)M"
        }
        else if thousand >= 1.0 {
            return "\(round(thousand*10)/10)K"
        }
        else {
            return "\(self)"
        }
    }
}

// iOS 17 has #Observble macro
@Observable
class SearchViewModel {
    
    var results: [Result] = [Result]()
    var isSearching = false
    
    var query = "Snapchat" {
        didSet {
            if oldValue != query {
                queryPublisher.send(query)
            }
        }
    }
    
    private var queryPublisher = PassthroughSubject<String, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        queryPublisher
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                self.fetchJSONData(searchValue: newValue)
            }.store(in: &cancellables)
    }
    
    private func fetchJSONData(searchValue: String) {
        Task {
            do {
                self.isSearching = true
                self.results = try await APIService.fetchSearchResults(searchValue: searchValue)
                self.isSearching = false
            } catch {
                self.isSearching = false
                print("Failed due to error:", error)
            }
        }
        
    }
}

struct SearchView: View {
    
    // ObservedObject <- more for dependency injection
    @State var vm = SearchViewModel()
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    if vm.results.isEmpty && vm.query.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 60))
                            Text("Please enter your search terms above")
                                .font(.system(size: 24, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            ForEach(vm.results) { result in
                                NavigationLink(destination: AppDetailView(trackId: result.trackId), label: {
                                    VStack(spacing: 16) {
                                        AppIconTitleView(result: result)
                                        
                                        ScreenshotsRow(proxy: proxy, result: result)
                                    }
                                    .foregroundStyle(Color(.label))
                                    .padding(16)
                                })
                                
                            }
                        }
                    }
                    
                }
            }
            .navigationTitle("Search")
            .searchable(text: $vm.query)
        }
    }
}

struct AppIconTitleView: View {
    let result: Result
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: result.artworkUrl512)) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: 80, height: 80)
            }
            
            VStack(alignment: .leading) {
                Text(result.trackName)
                    .lineLimit(1)
                    .font(.system(size: 20))
                Text(result.primaryGenreName)
                    .foregroundStyle(Color(.gray))
                
                HStack(spacing: 0) {
                    
                    ForEach(0..<Int(result.averageUserRating), id: \.self) { num in
                        Image(systemName: "star.fill")
                    }
                    
                    ForEach(0..<5 - Int(result.averageUserRating), id: \.self) { num in
                        Image(systemName: "star")
                    }
                    
                    Text("\(result.userRatingCount.roundedWithAbbreviations)")
                        .padding(.leading, 4)
                }
                .padding(.top, 0)
            }
            
            Spacer()
            
            Button(action: {
                
            }, label: {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 24))
            })
        }
    }
}

struct ScreenshotsRow: View {
    let proxy: GeometryProxy
    let result: Result
    
    var body: some View {
        let width = (proxy.size.width - 4 * 16) / 3
        
        HStack(spacing: 16) {
            ForEach(result.screenshotUrls.prefix(3), id: \.self) { screenshotURL in
                AsyncImage(url: URL(string: screenshotURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: width, height: 200)
                }
            }
        }
    }
}

#Preview {
    SearchView()
//        .preferredColorScheme(.dark)
}
