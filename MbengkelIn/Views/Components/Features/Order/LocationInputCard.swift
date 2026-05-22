//
//  LocationInputCard.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI

struct LocationInputCard: View {
    @Binding var address: String
    @Binding var isFocused: Bool
    let isFetchingLocation: Bool
    let onCurrentLocationTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Location")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                isFocused = true
            }) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.primary)
                        .font(.title2)
                    
                    Text(address.isEmpty ? "Enter breakdown location..." : address)
                        .font(.body)
                        .foregroundColor(address.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Button(action: {
                onCurrentLocationTapped()
            }) {
                HStack(spacing: 12) {
                    if isFetchingLocation {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                    } else {
                        Image(systemName: "location.north.circle.fill")
                            .foregroundColor(.primary)
                            .font(.title3)
                    }
                    
                    Text("Use current location")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .disabled(isFetchingLocation)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }
}
