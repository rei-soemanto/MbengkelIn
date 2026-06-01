//
//  BengkelRouteView.swift
//  MbengkelIn
//
//  Created by Amadeus Eugine Dirgantara on 29/05/26.
//

import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct BengkelRouteView: View {
    let order: NearbyOrder

    @StateObject private var viewModel = BengkelRouteViewModel()
    @StateObject private var chatWatch: ChatWatchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var region: MKCoordinateRegion
    @State private var didFitBoth = false
    @State private var showReportSheet = false
    @State private var reportReason = ""
    @State private var reportPhotoItem: PhotosPickerItem?
    @State private var reportPhotoData: Data?

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

    private var customerDistanceMeters: CLLocationDistance? {
        guard let me = viewModel.bengkelCoordinate else { return nil }
        return CLLocation(latitude: customerCoordinate.latitude, longitude: customerCoordinate.longitude)
            .distance(from: CLLocation(latitude: me.latitude, longitude: me.longitude))
    }
    private var isCustomerNear: Bool {
        if let d = customerDistanceMeters { return d <= 80 }
        return false
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
        .navigationBarBackButtonHidden(true)
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
        .onChange(of: viewModel.status) { newStatus in
            if newStatus == "Cancelled" {
                dismiss()
            }
        }
        .onDisappear {
            viewModel.stop()
            chatWatch.stop()
        }
        .sheet(isPresented: $showReportSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Laporkan kendala yang membuat pesanan tidak bisa diselesaikan. Sertakan bukti foto. Dana ditahan untuk ditinjau admin.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Alasan / kendala…", text: $reportReason, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    PhotosPicker(selection: $reportPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: reportPhotoData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                            Text(reportPhotoData == nil ? "Lampirkan Bukti Foto" : "Foto terlampir")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .onChange(of: reportPhotoItem) { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                reportPhotoData = data
                            }
                        }
                    }
                    Button {
                        Task {
                            if await viewModel.reportIssue(reason: reportReason, photoData: reportPhotoData) {
                                showReportSheet = false
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Kirim Laporan")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1))
                            .cornerRadius(12)
                    }
                    .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }
                .padding()
                .navigationTitle("Laporkan Kendala")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Batal") { showReportSheet = false }
                    }
                }
            }
            .presentationBackground(.white)
            .presentationDetents([.large])
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
                if viewModel.status == "On Progress" {
                    NavigationLink(destination: ChatView(serviceRequestId: order.id, title: order.customerName ?? "Pelanggan")) {
                        Image(systemName: "message.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                            .overlay(alignment: .topTrailing) {
                                UnreadBadge(count: chatWatch.unreadCount)
                            }
                    }
                    .simultaneousGesture(TapGesture().onEnded { chatWatch.markAllRead() })
                } else {
                    OrderStatusBadge(status: viewModel.status)
                }
            }

            if let info = order.vehicleInfo, !info.isEmpty {
                Label(info, systemImage: "car.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            switch viewModel.status {
            case "On Progress":
                CompleteOrderButton(requestId: order.id, isCustomer: false, canComplete: isCustomerNear)
                Button(role: .destructive) {
                    showReportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill")
                        Text("Laporkan Kendala").fontWeight(.semibold)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(12)
                }
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
