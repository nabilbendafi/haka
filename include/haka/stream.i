
%include haka/buffer.i

%define BASIC_STREAM(type)
%extend type {
	~type()
	{
		stream_destroy((struct stream *)$self);
	}

	struct buffer *read()
	{
		const size_t size = stream_available((struct stream *)$self);
		struct buffer *buf = allocate_buffer(size);
		if (!buf) return NULL;

		buf->size = stream_read((struct stream *)$self, buf->data, size);
		if (check_error()) {
			free_buffer(buf);
			return NULL;
		}
		return buf;
	}

	struct buffer *read(int size)
	{
		struct buffer *buf = allocate_buffer(size);
		if (!buf) return NULL;

		buf->size = stream_read((struct stream *)$self, buf->data, size);
		if (check_error()) {
			free_buffer(buf);
			return NULL;
		}
		return buf;
	}

	%rename(available) _available;
	unsigned int _available() {
		return stream_available((struct stream *)$self);
	}
}
%enddef