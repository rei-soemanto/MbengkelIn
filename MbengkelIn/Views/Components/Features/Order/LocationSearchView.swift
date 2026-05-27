//
//  LocationSearchView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//


import SwiftUI

struct LocationSearchView<VM: LocationSearchable>: View {
    @ObservedObject var viewModel: VM
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: {
                    isTextFieldFocused = false
                    viewModel.isEditingLocation = false
                    viewModel.searchResults = []
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.primary)
                        .font(.title2)
                    
                    TextField("Masukan lokasi...", text: $viewModel.locationAddress)
                        .font(.body)
                        .foregroundColor(.primary)
                        .focused($isTextFieldFocused)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 60)
            .padding(.bottom, 16)
            .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    Button(action: {
                        isTextFieldFocused = false
                        viewModel.useCurrentLocation()
                    }) {
                        HStack(spacing: 12) {
                            if viewModel.isFetchingLocation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                            } else {
                                Image(systemName: "location.north.circle.fill")
                                    .foregroundColor(.primary)
                                    .font(.title3)
                            }
                            
                            Text("Gunakan lokasi saat ini")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal)
                    }
                    .disabled(viewModel.isFetchingLocation)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    ForEach(viewModel.searchResults, id: \.self) { result in
                        Button(action: {
                            isTextFieldFocused = false
                            viewModel.selectSearchResult(result)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.properties.name ?? result.properties.street ?? "Lokasi tidak diketahui")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                let subtitleParts = [result.properties.street, result.properties.city, result.properties.state]
                                    .compactMap { $0 }
                                    .filter { !$0.isEmpty }
                                
                                if !subtitleParts.isEmpty {
                                    Text(subtitleParts.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGray6))
        }
        .background(Color(.systemGray6))
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
}
