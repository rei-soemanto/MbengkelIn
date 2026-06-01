//
//  BengkelRouteView.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct BengkelRouteView: View {
    let order: NearbyOrder

    @StateObject private var viewModel = BengkelRouteViewModel()
    @StateObject private var chatWatch: ChatWatchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var didFitBoth = false

    init(order: NearbyOrder) {
        self.order = order
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
        _chatWatch = StateObject(wrappedValue: ChatWatchViewModel(
            serviceRequestId: order.id,
            counterpartName: order.customerName ?? "Pelanggan"
        ))
    }

    private var customerCoordinate: CLLocationCoordinate2D {
        viewModel.customerLiveCoordinate
            ?? CLLocationCoordinate2D(latitude: order.latitude, longitude: order.longitude)
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(coordinateRegion: $region, annotationItems: pins) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(item.tint)
                            .clipShape(Circle())
                        Text(item.label)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                    }
                }
            }
            controlCard
        }
        .navigationTitle("Menuju Lokasi Pelanggan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
            }
        }
        .task { await viewModel.start(order: order) }
        .task { await chatWatch.start() }
        .onChange(of: viewModel.bengkelCoordinate?.latitude) { _ in fitBothIfNeeded() }
        .onDisappear {
            viewModel.stop()
            chatWatch.stop()
        }
    }

    private var pins: [TrackingPin] {
        var list = [TrackingPin(
            id: "customer",
            coordinate: customerCoordinate,
            label: order.customerName ?? "Pelanggan",
            icon: "person.fill",
            tint: .blue
        )]
        if let coord = viewModel.bengkelCoordinate {
            list.append(TrackingPin(
                id: "bengkel",
                coordinate: coord,
                label: "Anda",
                icon: "car.fill",
                tint: .primary
            ))
        }
        return list
    }

    private func fitBothIfNeeded() {
        guard !didFitBoth, let me = viewModel.bengkelCoordinate else { return }
        didFitBoth = true
        region = .fitting(customerCoordinate, me)
    }

    @ViewBuilder
    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3).foregroundColor(.white)
                    .padding(10).background(Color.primary).clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.serviceType ?? order.description ?? "Servis").font(.headline.bold())
                    Text(order.customerName ?? "Pelanggan")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                OrderStatusBadge(status: viewModel.status)
            }

            if let info = order.vehicleInfo, !info.isEmpty {
                Label(info, systemImage: "car.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            switch viewModel.status {
            case "On Progress":
                NavigationLink(destination: ChatView(serviceRequestId: order.id, title: order.customerName ?? "Pelanggan")) {
                    HStack {
                        Image(systemName: "message.fill")
                            .overlay(alignment: .topTrailing) {
                                UnreadBadge(count: chatWatch.unreadCount)
                            }
                        Text("Chat dengan Pelanggan").fontWeight(.bold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(Color(.systemBackground))
                    .padding()
                    .background(Color.primary.opacity(0.9))
                    .cornerRadius(12)
                }
                .simultaneousGesture(TapGesture().onEnded { chatWatch.markAllRead() })
                CompleteOrderButton(requestId: order.id, isCustomer: false)
            case "Done":
                statusLine(text: "Pesanan selesai.", icon: "checkmark.seal.fill", color: .green)
            case "Cancelled":
                statusLine(text: "Pesanan dibatalkan.", icon: "xmark.seal.fill", color: .red)
            default:
                statusLine(
                    text: "Tawaran terkirim. Menunggu konfirmasi pelanggan…",
                    icon: "paperplane.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 10, y: -2)
    }

    private func statusLine(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).fontWeight(.semibold)
            Spacer()
        }
        .font(.subheadline)
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }
}
