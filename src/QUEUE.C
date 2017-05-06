// ************************************************************************
// *
// *    File        : QUEUE.C
// *
// *    Description : Defines a queue object
// *
// *    Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#include <malloc.h>
#include <mem.h>
#include "queue.h"


Queue *CreateQueue(void)
{
        Queue   *q;

    q = malloc(sizeof(Queue));
    q->firstItem = q->lastItem = NULL;
    return q;
}

void DestroyQueue( Queue *q )
{
        QueueItem       *item, *item2;

        if( !q ) return;
    item = q->firstItem;
    while( item != NULL )
    {
        item2 = item->next;
                if(item->data) free(item->data);
        free(item);
        item = item2;
    }
    free(q);
}

void InsertQueueTop( Queue *q, void *data )
{
        QueueItem       *item = malloc(sizeof(QueueItem));

        if( !q ) return;
    if( !item ) return;
        item->next = q->firstItem;
    q->firstItem = item;
    if( q->lastItem == NULL ) q->lastItem = item;
    item->data = data;
}

void InsertQueueBottom( Queue *q, void *data )
{
        QueueItem       *item = malloc(sizeof(QueueItem));

        if( !q ) return;
    if( !item ) return;
        item->next = NULL;
    if( q->firstItem == NULL )
        {
                q->firstItem = q->lastItem = item;
    } else
    {
        q->lastItem->next = item;
        q->lastItem = item;
    }
    item->data = data;
}

void *GetQueueItem( Queue *q )
{
        void            *data;
        QueueItem       *item;

        if( !q || !q->firstItem ) return NULL;
        data = q->firstItem->data;
    item = q->firstItem->next;
    free(q->firstItem);
    if((q->firstItem = item) == NULL) q->lastItem = NULL;
        return data;
}

int SearchQueueItem( Queue *q, void *data, int dataSize )
{
        QueueItem       *item;

        if( !q ) return 0;
    item = q->firstItem;
    while( item && memcmp(data,item->data,dataSize) != 0 ) item = item->next;
    if( item ) return 1;
        else return 0;
}
