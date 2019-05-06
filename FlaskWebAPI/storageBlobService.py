import io
import os
import random
import time
import uuid

from azure.storage.blob import (
    BlockBlobService
)

class StorageBlobServiceWrapper():
    """
    This class wraps the Blob storage. Should be created in two phases. First passing the 
    account name and second passing the accountkey from the KeyValut. After this the service 
    object is created and can be used to access the blob items 
    """

    def __init__(self, account_name): 
        self.account_name=account_name
        self.account_key=None 
        self.service = None 

        self.container_name = 'listcontainer'
        self.blob_name = 'listblob'
        # our flag to ensure that the container and blobs are already created
        self._container_blob_created = False
        return

    def set_storageKey(self,storageKey):
        self.account_key=storageKey
        self.service = BlockBlobService(account_name= self.account_name, account_key=self.account_key)

    def get_blob_content(self):
        self._check_create_container_blob()
        blob = self.service.get_blob_to_text(self.container_name, self.blob_name)
        content = blob.content 
        return content

    def update_blob_content(self, txtcontent):
        self._check_create_container_blob()
        self.service.create_blob_from_text(self.container_name, self.blob_name, txtcontent)
        blob = self.service.get_blob_to_text(self.container_name, self.blob_name)
        content = blob.content 
        return content

    def _check_create_container_blob(self):
        if (not self.service):
            return 
        if (not self._container_blob_created):
            self._container_exists_create()
            self._blob_exists_create()
            self._container_blob_created = True

    def _container_exists_create(self):
        exists = self.service.exists(self.container_name)
        if (exists == False):
            self.service.create_container(self.container_name)
        exists = self.service.exists(self.container_name)
        return exists

    def _blob_exists_create(self):
        exists = self.service.exists(self.container_name, self.blob_name) 
        if (exists == False):
            # create an empty blob
            self.service.create_blob_from_text(self.container_name, self.blob_name, u'')
        exists = self.service.exists(self.container_name, self.blob_name)
        return exists



   

