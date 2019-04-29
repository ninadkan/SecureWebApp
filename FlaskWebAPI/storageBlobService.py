import io
import os
import random
import time
import uuid

from azure.storage.blob import (
    BlockBlobService
)

class StorageBlobServiceWrapper():
    def __init__(self, app): 
        self.account_name=app.config['account_name']
        self.account_key=app.config['account_key']
        self.sas_token=app.config['sas_token']
        
        if (self.sas_token and len(self.sas_token)>0):
            self.service = BlockBlobService(account_name= self.account_name, sas_token=self.sas_token)
        else:
            self.service = BlockBlobService(account_name= self.account_name, account_key=self.account_key)

        self.container_name = 'listcontainer'
        self.blob_name = 'listblob'
        self._container_exists_create()
        self._blob_exists_create()
        return

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

    def get_blob_content(self):
        blob = self.service.get_blob_to_text(self.container_name, self.blob_name)
        content = blob.content 
        return content

    def update_blob_content(self, txtcontent):
        self.service.create_blob_from_text(self.container_name, self.blob_name, txtcontent)
        blob = self.service.get_blob_to_text(self.container_name, self.blob_name)
        content = blob.content 
        return content

   

