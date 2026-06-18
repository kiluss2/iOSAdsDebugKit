import UIKit

extension UITableView {
    func adsDebugReloadDataPreservingVisibleItem<Key: Equatable>(
        anchorKeyForVisibleCell: (IndexPath, UITableViewCell) -> Key?,
        indexPathForKey: (Key) -> IndexPath?
    ) {
        let topOffset = -adjustedContentInset.top
        guard contentOffset.y > topOffset + 2 else {
            reloadData()
            return
        }

        let visibleTopY = contentOffset.y + adjustedContentInset.top
        let visibleIndexPaths = (indexPathsForVisibleRows ?? [])
            .sorted { rectForRow(at: $0).minY < rectForRow(at: $1).minY }

        var anchor: (key: Key, offset: CGFloat)?
        for indexPath in visibleIndexPaths {
            let rect = self.rectForRow(at: indexPath)
            guard rect.maxY > visibleTopY,
                  let cell = self.cellForRow(at: indexPath),
                  let key = anchorKeyForVisibleCell(indexPath, cell) else {
                continue
            }
            anchor = (key, visibleTopY - rect.minY)
            break
        }

        guard let anchor else {
            reloadData()
            return
        }

        let oldContentOffsetX = contentOffset.x
        UIView.performWithoutAnimation {
            reloadData()
            layoutIfNeeded()

            guard let newIndexPath = indexPathForKey(anchor.key) else {
                let maxOffsetY = max(topOffset, contentSize.height - bounds.height + adjustedContentInset.bottom)
                let clampedY = min(max(contentOffset.y, topOffset), maxOffsetY)
                setContentOffset(CGPoint(x: oldContentOffsetX, y: clampedY), animated: false)
                return
            }

            let newVisibleTopY = rectForRow(at: newIndexPath).minY + anchor.offset
            let maxOffsetY = max(topOffset, contentSize.height - bounds.height + adjustedContentInset.bottom)
            let targetOffsetY = min(max(newVisibleTopY - adjustedContentInset.top, topOffset), maxOffsetY)
            setContentOffset(CGPoint(x: oldContentOffsetX, y: targetOffsetY), animated: false)
        }
    }
}
