//
//  BengkelDashboardView.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 25/04/26.
//

import SwiftUI

struct BengkelDashboardView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @StateObject private var bengkelViewModel = BengkelViewModel()
    
    @State private var hasActiveJob: Bool = false
    @State private var todaysEarnings: Double = 0.0
    @State private var pendingRequestsCount: Int = 1
    
    @State private var incomingJobTitle: String = "Flat Tire - Honda Brio"
    @State private var incomingJobDistance: Double = 2.4
    @State private var activeJobTitle: String = "Fixing Flat Tire - Honda Brio"
    @State private var activeJobStatus: String = "Job is currently in progress..."
    
    var realShopRating: Double {
        bengkelViewModel.myBengkel?.averageRating ?? 0.0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider Dashboard")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text(bengkelViewModel.myBengkel?.name ?? "Manage Your Shop")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shop Rating")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if bengkelViewModel.isLoading && bengkelViewModel.myBengkel == nil {
                        ProgressView()
                    } else {
                        HStack(spacing: 12) {
                            Text(String(format: "%.1f", realShopRating))
                                .font(.title)
                                .fontWeight(.bold)
                            
                            StarRatingView(rating: realShopRating)
                            
                            Spacer()
                            
                            Text("(\(bengkelViewModel.myBengkel?.totalReviews ?? 0) Reviews)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Earnings")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text(formatToRupiah(todaysEarnings))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(hasActiveJob ? "Current Active Job" : "Incoming Requests")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if !hasActiveJob && pendingRequestsCount > 0 {
                            Text("\(pendingRequestsCount) Pending")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    if hasActiveJob {
                        VStack(spacing: 12) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                                .padding(.bottom, 4)
                            
                            Text(activeJobTitle)
                                .font(.headline)
                            
                            Text(activeJobStatus)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button("Finish Job") {
                                // ADD LOGIC TO FINISH JOB
                                withAnimation {
                                    hasActiveJob = false
                                    if pendingRequestsCount > 0 {
                                        pendingRequestsCount -= 1
                                    }
                                    todaysEarnings += 150000
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.top, 12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                        
                    } else {
                        if pendingRequestsCount > 0 {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                    .padding(.bottom, 4)
                                
                                Text(incomingJobTitle)
                                    .font(.headline)
                                
                                Text(String(format: "Distance: %.1f km away", incomingJobDistance))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Button("Accept Job Offer") {
                                    //ADD LOGIC TO BID PRICE
                                    withAnimation { hasActiveJob = true }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No incoming requests")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .task {
            if let uid = authViewModel.currentUser?.id {
                await bengkelViewModel.fetchMyBengkel(uid: uid)
            }
        }
    }
    
    private func formatToRupiah(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "Rp 0"
    }
}

#Preview ("Light Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel())
        .preferredColorScheme(.light)
}

#Preview ("Dark Mode") {
    BengkelDashboardView(authViewModel: AuthViewModel())
        .preferredColorScheme(.dark)
}
