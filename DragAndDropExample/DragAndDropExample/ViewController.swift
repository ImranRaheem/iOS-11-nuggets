//
//  ViewController.swift
//  DragAndDropExample
//
//  Created by imran on 28/6/17.
//  Copyright © 2017 Imran. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: ivars
    @IBOutlet weak var collectionView: UICollectionView!
    
    private lazy var images: [UIImage] = {
        var array = [UIImage]()
        for i in 1...10 {
            if let image = UIImage(named: "Image\(i)") {
                array.append(image)
            }
        }
        return array
    }()
    
    private var draggedIndexPaths = [IndexPath]()
    private let kCellIdentifier = "ImageCell"
    
    //MARK: view lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: kCellIdentifier)
        
        // Drag & Drop delegates
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

// MARK: Drag
extension ViewController: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        draggedIndexPaths.removeAll()
        draggedIndexPaths.append(indexPath)
        
        let cell = collectionView.cellForItem(at: indexPath) as! ImageCell
        let imageItemProvider = NSItemProvider(object: cell.imageView.image!)
        return [UIDragItem(itemProvider: imageItemProvider)]
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        draggedIndexPaths.append(indexPath)
        
        let cell = collectionView.cellForItem(at: indexPath) as! ImageCell
        let imageItemProvider = NSItemProvider(object: cell.imageView.image!)
        return [UIDragItem(itemProvider: imageItemProvider)]
    }
}

// MARK: Drop
extension ViewController: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
        
        // loads objects on main thread
        coordinator.session.loadObjects(ofClass: UIImage.self) { imageItems in
            
            var i = 0
            for item in imageItems {
                if let image = item as? UIImage {
                    // Local drag
                    if case .move = coordinator.proposal.operation {
                        // replace images
                        self.images.remove(at: self.draggedIndexPaths[i].row)
                        self.images.insert(image, at: destinationIndexPath.row)
                    }
                    else if case .copy = coordinator.proposal.operation {
                        // add images
                        self.images.insert(image, at: destinationIndexPath.row)
                        collectionView.insertItems(at: [destinationIndexPath])
                    }
                }
                i += 1
            }
            collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
//             This results in crash with reason: 'attempt to create view animation for nil view'
//             Reported here: http://www.openradar.me/28163205
//
//            let indexSet = IndexSet(integer: 0)
//            collectionView.reloadSections(indexSet)
        }
    }
    
    // Drop proposal
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        
        if session.localDragSession != nil {
            return UICollectionViewDropProposal(dropOperation: .move, intent: .insertAtDestinationIndexPath)
        }
        else {
            return UICollectionViewDropProposal(dropOperation: .copy, intent: .insertIntoDestinationIndexPath)
        }
    }
}

// MARK: UICollectionView Data Source
extension ViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: kCellIdentifier, for: indexPath) as! ImageCell
        
        cell.imageView.image = images[indexPath.row]
        
        return cell
    }
    
}

