//
//  OrderView.swift
//  MbengkelIn
//
//  Created by Bryan Fernando Dinata on 19/05/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct OrderView: View {
    @StateObject private var viewModel = OrderViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                OrderMapView(
                    region: $viewModel.region,
                    isEditing: viewModel.isEditingLocation,
                    onRegionChange: { coordinate in
                        viewModel.updateLocationFromMap(coordinate: coordinate)
                    }
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Image(systemName: "mappin")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Circle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(x: 2, y: 1)
                        .padding(.top, -2)
                }
                .padding(.bottom, 40)
            }
            
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    Spacer()
                }
                .padding(.top, 0)
                .padding(.leading, 20)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                LocationInputCard(
                    address: $viewModel.locationAddress,
                    isFocused: $viewModel.isEditingLocation,
                    isFetchingLocation: viewModel.isFetchingLocation,
                    onCurrentLocationTapped: viewModel.useCurrentLocation
                )
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Perlu bantuan apa?")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.services, id: \.self) { service in
                                ServicePill(
                                    title: service,
                                    isSelected: viewModel.selectedService == service,
                                    action: { viewModel.selectService(service) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if viewModel.estimatedPrice > 0 {
                        HStack {
                            Text("Estimated Cost")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Rp\(viewModel.estimatedPrice)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
                    PrimaryButton(
                        title: "Cari Mechanic",
                        iconName: "wrench.and.screwdriver.fill",
                        action: viewModel.createOrder
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
                .background(Color(.systemBackground))
            }
            .opacity(viewModel.isEditingLocation ? 0 : 1)
            .disabled(viewModel.isEditingLocation)
            
            if viewModel.isEditingLocation {
                LocationSearchView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .navigationDestination(isPresented: $viewModel.navigateToBidding) {
            CustomerBiddingView(
                serviceRequestId: viewModel.createdServiceRequestId ?? "",
                coordinate: viewModel.region.center
            )
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isEditingLocation)
        .onAppear {
            viewModel.useCurrentLocation()
        }
    }
}

#Preview {
    OrderView()
}
