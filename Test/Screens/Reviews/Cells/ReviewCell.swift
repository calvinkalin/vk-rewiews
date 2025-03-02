import UIKit

/// Конфигурация ячейки. Содержит данные для отображения в ячейке.
struct ReviewCellConfig {
    
    /// Идентификатор для переиспользования ячейки.
    static let reuseId = String(describing: ReviewCellConfig.self)
    
    /// Идентификатор конфигурации. Можно использовать для поиска конфигурации в массиве.
    let id = UUID()
    /// Текст отзыва.
    let reviewText: NSAttributedString
    
    var isExpanded: Bool = false
    var maxLines: Int {
        return isExpanded ? 0 : 3
    }
    /// Время создания отзыва.
    let created: NSAttributedString
    
    let avatarURL: String?
    let firstName: String
    let lastName: String
    let rating: Int
    /// Замыкание, вызываемое при нажатии на кнопку "Показать полностью...".
    let onTapShowMore: (UUID) -> Void
    
    var shouldShowShowMoreButton: Bool {
        let textHeight = layout.calculateReviewTextHeight(config: self)
        let maxTextHeight = layout.calculateTextHeightForLines(maxLines: 3)
        return textHeight > maxTextHeight
    }
    
    /// Объект, хранящий посчитанные фреймы для ячейки отзыва.
    fileprivate let layout = ReviewCellLayout()
    
}

// MARK: - TableCellConfig

extension ReviewCellConfig: TableCellConfig {
    
    /// Метод обновления ячейки.
    /// Вызывается из `cellForRowAt:` у `dataSource` таблицы.
    func update(cell: UITableViewCell) {
        guard let cell = cell as? ReviewCell else { return }
        cell.update(with: self)
        cell.config = self
    }
    
    /// Метод, возвращаюший высоту ячейки с данным ограничением по размеру.
    /// Вызывается из `heightForRowAt:` делегата таблицы.
    func height(with size: CGSize) -> CGFloat {
        layout.height(config: self, maxWidth: size.width)
    }
    
}

// MARK: - Private

private extension ReviewCellConfig {
    
    /// Текст кнопки "Показать полностью...".
    static let showMoreText = "Показать полностью..."
        .attributed(font: .showMore, color: .showMore)
    
}

// MARK: - Cell

final class ReviewCell: UITableViewCell {
    
    fileprivate var config: Config?
    
    fileprivate let reviewTextLabel = UILabel()
    fileprivate let createdLabel = UILabel()
    fileprivate let showMoreButton = UIButton()
    fileprivate let avatarImageView = UIImageView()
    fileprivate let usernameLabel = UILabel()
    fileprivate let ratingImageView = UIImageView()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let layout = config?.layout else { return }
        
        reviewTextLabel.frame = layout.reviewTextLabelFrame
        createdLabel.frame = layout.createdLabelFrame
        showMoreButton.frame = layout.showMoreButtonFrame
        avatarImageView.frame = layout.avatarFrame
        usernameLabel.frame = layout.usernameFrame
        ratingImageView.frame = layout.ratingFrame
    }
    
    @objc private func didTapShowMore() {
        guard let config = config else { return }
        config.onTapShowMore(config.id)
    }
}

// MARK: - Private

private extension ReviewCell {
    func update(with config: ReviewCellConfig) {
        if let avatar = ImageLoader.shared.image(for: config.avatarURL) {
            avatarImageView.image = avatar
        } else {
            avatarImageView.image = UIImage(named: "avatar")
        }
        
        usernameLabel.text = "\(config.firstName) \(config.lastName)"
        reviewTextLabel.attributedText = config.reviewText
        reviewTextLabel.numberOfLines = config.maxLines
        createdLabel.attributedText = config.created
        
        let ratingRenderer = RatingRenderer(config: .default())
        ratingImageView.image = ratingRenderer.ratingImage(config.rating)
        
        showMoreButton.isHidden = !config.shouldShowShowMoreButton
        showMoreButton.setAttributedTitle(ReviewCellConfig.showMoreText, for: .normal)
        showMoreButton.sizeToFit()
        
        NotificationCenter.default.addObserver(self, selector: #selector(imageLoaded(_:)), name: .imageLoaded, object: nil)
    }
    
    @objc private func imageLoaded(_ notification: Notification) {
        DispatchQueue.main.async {
            self.avatarImageView.image = ImageLoader.shared.image(for: self.config?.avatarURL)
        }
    }
}

private extension ReviewCell {
    
    func setupCell() {
        setupReviewTextLabel()
        setupCreatedLabel()
        setupShowMoreButton()
        setupAvatarImageView()
        setupUsernameLabel()
        setupRatingImageView()
        
    }
    
    func setupReviewTextLabel() {
        contentView.addSubview(reviewTextLabel)
        reviewTextLabel.lineBreakMode = .byWordWrapping
        reviewTextLabel.font = .text
        reviewTextLabel.textColor = .label
        reviewTextLabel.numberOfLines = 3
    }
    
    func setupCreatedLabel() {
        contentView.addSubview(createdLabel)
        createdLabel.font = .created
        createdLabel.textColor = .created
    }
    
    func setupShowMoreButton() {
        contentView.addSubview(showMoreButton)
        showMoreButton.contentVerticalAlignment = .fill
        showMoreButton.setAttributedTitle(Config.showMoreText, for: .normal)
        showMoreButton.titleLabel?.font = .showMore
        showMoreButton.setTitleColor(.showMore, for: .normal)
        showMoreButton.addTarget(self, action: #selector(didTapShowMore), for: .touchUpInside)
    }
    
    func setupAvatarImageView() {
        contentView.addSubview(avatarImageView)
        avatarImageView.layer.cornerRadius = ReviewCellLayout.avatarCornerRadius
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.shouldRasterize = true
        avatarImageView.layer.rasterizationScale = UIScreen.main.scale
    }
    
    func setupUsernameLabel() {
        contentView.addSubview(usernameLabel)
        usernameLabel.font = .username
        usernameLabel.textColor = .label
    }
    
    func setupRatingImageView() {
        contentView.addSubview(ratingImageView)
    }
}


// MARK: - Layout

/// Класс, в котором происходит расчёт фреймов для сабвью ячейки отзыва.
/// После расчётов возвращается актуальная высота ячейки.
private final class ReviewCellLayout {
    
    // MARK: - Размеры
    
    fileprivate static let avatarSize = CGSize(width: 36.0, height: 36.0)
    fileprivate static let avatarCornerRadius = 18.0
    fileprivate static let photoCornerRadius = 8.0
    
    private static let photoSize = CGSize(width: 55.0, height: 66.0)
    private static let showMoreButtonSize = Config.showMoreText.size()
    
    // MARK: - Фреймы
    
    private(set) var reviewTextLabelFrame = CGRect.zero
    private(set) var showMoreButtonFrame = CGRect.zero
    private(set) var createdLabelFrame = CGRect.zero
    private(set) var avatarFrame = CGRect.zero
    private(set) var usernameFrame = CGRect.zero
    private(set) var ratingFrame = CGRect.zero
    
    // MARK: - Отступы
    
    /// Отступы от краёв ячейки до её содержимого.
    private let insets = UIEdgeInsets(top: 9.0, left: 12.0, bottom: 9.0, right: 12.0)
    
    /// Горизонтальный отступ от аватара до имени пользователя.
    private let avatarToUsernameSpacing = 10.0
    /// Вертикальный отступ от имени пользователя до вью рейтинга.
    private let usernameToRatingSpacing = 6.0
    /// Вертикальный отступ от вью рейтинга до текста (если нет фото).
    private let ratingToTextSpacing = 6.0
    /// Вертикальный отступ от вью рейтинга до фото.
    private let ratingToPhotosSpacing = 10.0
    /// Горизонтальные отступы между фото.
    private let photosSpacing = 8.0
    /// Вертикальный отступ от фото (если они есть) до текста отзыва.
    private let photosToTextSpacing = 10.0
    /// Вертикальный отступ от текста отзыва до времени создания отзыва или кнопки "Показать полностью..." (если она есть).
    private let reviewTextToCreatedSpacing = 6.0
    /// Вертикальный отступ от кнопки "Показать полностью..." до времени создания отзыва.
    private let showMoreToCreatedSpacing = 6.0
    
    // MARK: - Расчёт фреймов и высоты ячейки
    
    func height(config: ReviewCellConfig, maxWidth: CGFloat) -> CGFloat {
        let width = maxWidth - insets.left - insets.right
        var maxY = insets.top
        
        // Аватар
        avatarFrame = CGRect(x: insets.left, y: maxY, width: Self.avatarSize.width, height: Self.avatarSize.height)
        
        // Имя пользователя
        usernameFrame = CGRect(x: avatarFrame.maxX + avatarToUsernameSpacing, y: maxY, width: width - (avatarFrame.maxX + avatarToUsernameSpacing), height: 20)
        maxY += usernameFrame.height + usernameToRatingSpacing
        
        // Рейтинг
        ratingFrame = CGRect(x: usernameFrame.minX, y: maxY, width: 80, height: 16)
        maxY += ratingFrame.height + ratingToTextSpacing
        
        if !config.reviewText.isEmpty() {
            // Высота текста с текущим ограничением по количеству строк.
            let currentTextHeight = (config.reviewText.font()?.lineHeight ?? .zero) * CGFloat(config.maxLines)
            // Максимально возможная высота текста, если бы ограничения не было.
            let actualTextHeight = config.reviewText.boundingRect(width: width).size.height
            
            reviewTextLabelFrame = CGRect(
                origin: CGPoint(x: avatarFrame.maxX + avatarToUsernameSpacing, y: maxY),
                size: config.reviewText.boundingRect(width: width - (usernameFrame.minX - insets.left), height: currentTextHeight).size
            )
            
            maxY = reviewTextLabelFrame.maxY + reviewTextToCreatedSpacing
        }
        
        // Кнопка "Показать полностью..."
        if config.shouldShowShowMoreButton {
            showMoreButtonFrame = CGRect(x: usernameFrame.minX, y: maxY, width: 170, height: 30)
            maxY += showMoreButtonFrame.height + showMoreToCreatedSpacing
        } else {
            showMoreButtonFrame = .zero
        }
        
        // Время создания отзыва
        createdLabelFrame = CGRect(x: usernameFrame.minX, y: maxY, width: width - (usernameFrame.minX - insets.left), height: 20)
        
        return createdLabelFrame.maxY + insets.bottom
    }
    
    func calculateReviewTextHeight(config: ReviewCellConfig) -> CGFloat {
        let width = UIScreen.main.bounds.width - 24
        let boundingSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        return config.reviewText.boundingRect(with: boundingSize, options: .usesLineFragmentOrigin, context: nil).height
    }
    
    func calculateTextHeightForLines(maxLines: Int) -> CGFloat {
        return 20 * CGFloat(maxLines)
    }
}

// MARK: - Конфигурация ячейки для отображения общего количества отзывов.
struct ReviewCountCellConfig {
    static let reuseId = String(describing: ReviewCountCellConfig.self)
    
    let reviewCount: Int
}

extension ReviewCountCellConfig: TableCellConfig {
    func update(cell: UITableViewCell) {
        guard let cell = cell as? ReviewCountCell else { return }
        cell.update(with: self)
    }
    
    func height(with size: CGSize) -> CGFloat {
        return 44 // Высота ячейки с количеством отзывов
    }
}

final class ReviewCountCell: UITableViewCell {
    private let countLabel = UILabel()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    private func setupCell() {
        contentView.addSubview(countLabel)
        countLabel.textAlignment = .center
        countLabel.font = .boldSystemFont(ofSize: 16)
        countLabel.textColor = .label
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        countLabel.frame = contentView.bounds
    }
    
    func update(with config: ReviewCountCellConfig) {
        countLabel.text = "\(config.reviewCount) отзывов"
        countLabel.font = .reviewCount
        countLabel.textColor = .reviewCount
    }
}

// MARK: - Typealias

fileprivate typealias Config = ReviewCellConfig
fileprivate typealias Layout = ReviewCellLayout
