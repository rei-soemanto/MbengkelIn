import Foundation
import CoreLocation

class LocationService {
    func searchOSM(query: String, coordinate: CLLocationCoordinate2D) async throws -> [PhotonSearchFeature] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://photon.komoot.io/api/?q=\(encodedQuery)&limit=5&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)") else {
            return []
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(PhotonSearchResponse.self, from: data)
        return result.features
    }
    
    func fetchAddress(from coordinate: CLLocationCoordinate2D) async throws -> String? {
        let urlString = "https://photon.komoot.io/reverse?lon=\(coordinate.longitude)&lat=\(coordinate.latitude)"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let photonResponse = try JSONDecoder().decode(PhotonSearchResponse.self, from: data)
        
        if let properties = photonResponse.features.first?.properties {
            let addressParts = [properties.name, properties.street, properties.city, properties.state]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            return addressParts.joined(separator: ", ")
        }
        return nil
    }
}
