import Foundation

enum DateParsing {
    static func parse(_ string: String) -> DateComponents? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: string) {
            return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        }

        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: string) {
            return Calendar.current.dateComponents([.year, .month, .day], from: date)
        }

        return nil
    }
}
