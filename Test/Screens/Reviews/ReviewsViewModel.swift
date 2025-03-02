import UIKit

/// Класс, описывающий бизнес-логику экрана отзывов.
final class ReviewsViewModel: NSObject {
    
    /// Замыкание, вызываемое при изменении `state`.
    var onStateChange: ((State) -> Void)?
    
    private var state: State
    private let reviewsProvider: ReviewsProvider
    private let ratingRenderer: RatingRenderer
    private let decoder: JSONDecoder
    
    init(
        state: State = State(),
        reviewsProvider: ReviewsProvider = ReviewsProvider(),
        ratingRenderer: RatingRenderer = RatingRenderer(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.state = state
        self.reviewsProvider = reviewsProvider
        self.ratingRenderer = ratingRenderer
        self.decoder = decoder
    }
    
}

// MARK: - Internal

extension ReviewsViewModel {
    
    typealias State = ReviewsViewModelState
    
    /// Метод получения отзывов.
    func getReviews() {
        guard state.shouldLoad else { return }
        state.shouldLoad = false
        reviewsProvider.getReviews(offset: state.offset, completion: gotReviews)
        print("Загрузка отзывов с offset: \(state.offset)")
    }

    
}

// MARK: - Private

private extension ReviewsViewModel {
    
    /// Метод обработки получения отзывов.
    func gotReviews(_ result: ReviewsProvider.GetReviewsResult) {
        do {
            let data = try result.get()
            let reviews = try decoder.decode(Reviews.self, from: data)
            let newItems = reviews.items.map(makeReviewItem)
            print("Загружено \(newItems.count) отзывов") // Проверка
            
            // Добавляем новые отзывы в список
            state.items += newItems
            
            // Обновляем состояние
            state.offset += state.limit
            
            // Проверка, есть ли ещё отзывы для загрузки
            state.shouldLoad = state.offset < reviews.count
            
            // Если новых отзывов не осталось, останавливаем дальнейшую загрузку
            if !state.shouldLoad {
                print("Больше отзывов нет для загрузки.")
                
                // Теперь добавляем ячейку с общим количеством отзывов, если она ещё не была добавлена
                if !state.items.contains(where: { $0 is ReviewCountCellConfig }) {
                    let reviewCountConfig = ReviewCountCellConfig(reviewCount: reviews.count)
                    state.items.append(reviewCountConfig)
                }
            }
        } catch {
            state.shouldLoad = true
            print("Ошибка загрузки отзывов: \(error)")
        }
        onStateChange?(state)
    }

    /// Метод, вызываемый при нажатии на кнопку "Показать полностью...".
    /// Снимает ограничение на количество строк текста отзыва (раскрывает текст).
    func showMoreReview(with id: UUID) {
        guard
            let index = state.items.firstIndex(where: { ($0 as? ReviewItem)?.id == id }),
            var item = state.items[index] as? ReviewItem
        else { return }
        item.maxLines = .zero
        state.items[index] = item
        onStateChange?(state)
    }
    
}

// MARK: - Items

private extension ReviewsViewModel {
    
    typealias ReviewItem = ReviewCellConfig
    
    func makeReviewItem(_ review: Review) -> ReviewItem {
        let reviewText = review.text.attributed(font: .text)
        let created = review.created.attributed(font: .created, color: .created)
        let item = ReviewItem(
            reviewText: reviewText,
            created: created,
            avatar: UIImage(named: "avatar") ?? UIImage(),
            firstName: review.firstName,
            lastName: review.lastName,
            rating: review.rating,
            onTapShowMore: showMoreReview
        )
        return item
    }
    
}

// MARK: - UITableViewDataSource

extension ReviewsViewModel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        state.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let config = state.items[indexPath.row]
        let cell: UITableViewCell
        
        if let reviewConfig = config as? ReviewCellConfig {
            cell = tableView.dequeueReusableCell(withIdentifier: ReviewCellConfig.reuseId, for: indexPath)
            reviewConfig.update(cell: cell)
        } else if let reviewCountConfig = config as? ReviewCountCellConfig {
            cell = tableView.dequeueReusableCell(withIdentifier: ReviewCountCellConfig.reuseId, for: indexPath)
            reviewCountConfig.update(cell: cell)
        } else {
            fatalError("Unknown config type")
        }
        
        return cell
    }
}


// MARK: - UITableViewDelegate

extension ReviewsViewModel: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        state.items[indexPath.row].height(with: tableView.bounds.size)
    }
    
    /// Метод дозапрашивает отзывы, если до конца списка отзывов осталось два с половиной экрана по высоте.
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        if shouldLoadNextPage(scrollView: scrollView, targetOffsetY: targetContentOffset.pointee.y) {
            getReviews()
        }
    }
    
    private func shouldLoadNextPage(
        scrollView: UIScrollView,
        targetOffsetY: CGFloat,
        screensToLoadNextPage: Double = 2.5
    ) -> Bool {
        let viewHeight = scrollView.bounds.height
        let contentHeight = scrollView.contentSize.height
        let triggerDistance = viewHeight * screensToLoadNextPage
        let remainingDistance = contentHeight - viewHeight - targetOffsetY
        return remainingDistance <= triggerDistance
    }
    
}
