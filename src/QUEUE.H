// ************************************************************************
// *
// *	File        : QUEUE.H
// *
// *	Description : Header file for queue object
// *
// *	Copyright (C) 1993 Otto Chrons
// *
// ************************************************************************

#ifndef __QUEUE_H
#define __QUEUE_H

typedef struct _q_item {
    void			*data;
	struct _q_item	*next;
} QueueItem;

typedef struct {
    QueueItem  *firstItem, *lastItem;
} Queue;

Queue *CreateQueue(void);
void DestroyQueue( Queue *q );
void InsertQueueTop( Queue *q, void *item );
void InsertQueueBottom( Queue *q, void *item );
void *GetQueueItem(Queue *q );
int SearchQueueItem( Queue *q, void *item, int itemSize );

#endif