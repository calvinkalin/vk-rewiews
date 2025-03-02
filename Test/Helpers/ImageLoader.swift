import UIKit

final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()

    func image(for urlString: String?) -> UIImage? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                self.cache.setObject(image, forKey: urlString as NSString)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .imageLoaded, object: urlString)
                }
            }
        }
        return nil
    }
}

extension Notification.Name {
    static let imageLoaded = Notification.Name("imageLoaded")
}
