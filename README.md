# EPUBKit

Example:
```swift 
let epub = try EPUB(fileURL: #{EPUB URL})

let observationForState = epub.$state
    .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
    .sink {
        switch $0 {
        case .closed:
            // epub.metadata can be accesed in this state
            epub.open { (result) in
                switch result {
                case .success:
                    // Open epub files using epub.resourceURL
                case .failure(let error):
                    break
                }
            }
        default:
            break
        }
    }
```
