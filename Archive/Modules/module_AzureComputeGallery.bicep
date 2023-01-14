@description('Object containing the gallery configuration information (from config)')
param imageGalleryObject object
//Format:
// {
//   sharedImageGallerySubscriptionID: gallery subscription id
//   sharedImageGalleryRG: gallery resource group
//   sharedImageGalleryName: gallery name
// }

@description('The name of the image container that contains the list of images.  Usually will be the name of a service defined in the builder e.g. UDALPaymentGrouper')
param imageContainerName string

@description('Optional - The version of the image to return.  Default: latest')
param imageVersion string = 'latest'

resource ImageGallery 'Microsoft.Compute/galleries@2021-10-01' existing = {
  name: imageGalleryObject.sharedImageGalleryName
  scope: resourceGroup(imageGalleryObject.sharedImageGallerySubscriptionID,imageGalleryObject.sharedImageGalleryRG)

}

resource ImageContainer 'Microsoft.Compute/galleries/images@2021-10-01' existing = {
  name: imageContainerName
  parent: ImageGallery
}

resource Image 'Microsoft.Compute/galleries/images/versions@2021-10-01' existing = {
  name: imageVersion
  parent: ImageContainer
}

//the id of the gallery itself
//e.g. '/subscriptions/mysubid/resourceGroups/galleryRG/providers/Microsoft.Compute/galleries/galleryName'

output imageGalleryID string = ImageGallery.id

//the combined id of gallery and definition up to version
//e.g. '/subscriptions/mysubid/resourceGroups/galleryRG/providers/Microsoft.Compute/galleries/galleryName/images/galleryContainerName'
output imageContainerID string = ImageContainer.id
//Add more such as EOL, architecture etc.

//the full ID of the image including gallery, definition and verison
//e.g. '/subscriptions/mysubid/resourceGroups/galleryRG/providers/Microsoft.Compute/galleries/galleryName/images/galleryContainerName/versions/latest'
output imageID string = Image.id
